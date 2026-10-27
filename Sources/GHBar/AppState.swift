import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
  @Published var config: AppConfig
  @Published private(set) var selectedSource: OrgSource?
  @Published var repoGroups: [RepoGroup] = []
  @Published var pullRequests: [String: [PRViewModel]] = [:]
  @Published var isLoading = false
  @Published var lastRefresh: Date?
  @Published var lastError: String?
  @Published var selectedTab: Tab = .actions
  @Published var mostRecentRepoId: String?
  /// Worst of the latest run per workflow and your PRs' CI; drives the menu bar dot.
  @Published private(set) var overallStatus: RunStatus = .unknown
  @Published private(set) var launchAtLogin = LoginItem.isEnabled

  enum Tab: String, CaseIterable {
    case actions = "Actions"
    case prs = "PRs"
  }

  private var timer: Timer?
  private(set) var isPopoverVisible = false
  private var configError: String?
  private var configModified: Date?
  /// Login from `gh api user`, kept across config reloads when `username` is empty.
  private var resolvedUsername: String?

  /// Only one refresh is in flight. Each new one cancels the previous and bumps the
  /// generation, so a slower, older refresh can never overwrite newer results.
  private var refreshTask: Task<Void, Never>?
  private var refreshGeneration = 0

  init() {
    self.config = .default
    loadConfig()
  }

  /// Called once at launch: starts background polling so the menu bar dot is live.
  func start() {
    schedulePolling()
    if config.backgroundPollingMinutes > 0 { requestRefresh() }
  }

  // MARK: - Config

  func reloadConfigIfChanged() {
    guard AppConfig.modificationDate() != configModified else { return }
    loadConfig()
    schedulePolling()
  }

  private func loadConfig() {
    var (cfg, error) = AppConfig.load()
    configModified = AppConfig.modificationDate()
    if cfg.username.isEmpty, let resolvedUsername { cfg.username = resolvedUsername }
    config = cfg
    configError = error
    lastError = error

    if let current = selectedSource, cfg.allSources.contains(current) { return }
    selectedSource = cfg.allSources.first
    clearData()
  }

  func openConfigFile() {
    let url = AppConfig.configFile
    if !FileManager.default.fileExists(atPath: url.path) { AppConfig.default.save() }
    // .json may have no default app; fall back to TextEdit
    if NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
      NSWorkspace.shared.open(url)
    } else {
      NSWorkspace.shared.open(
        [url],
        withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"),
        configuration: NSWorkspace.OpenConfiguration()
      )
    }
  }

  func setLaunchAtLogin(_ enabled: Bool) {
    do {
      try LoginItem.setEnabled(enabled)
    } catch {
      lastError = "Could not change open-at-login: \(error.localizedDescription)"
    }
    launchAtLogin = LoginItem.isEnabled
  }

  var availableSources: [OrgSource] {
    config.allSources
  }

  // MARK: - Polling

  func popoverOpened() {
    isPopoverVisible = true
    launchAtLogin = LoginItem.isEnabled
    reloadConfigIfChanged()
    requestRefresh()
    schedulePolling()
  }

  func popoverClosed() {
    isPopoverVisible = false
    // Let an in-flight refresh finish if it will feed the menu bar dot
    if config.backgroundPollingMinutes == 0 { cancelRefresh() }
    schedulePolling()
  }

  /// Fast polling while the popover is open, slow (or none) while it is closed.
  private func schedulePolling() {
    stopPolling()
    let interval: TimeInterval
    if isPopoverVisible {
      interval = TimeInterval(config.pollingIntervalSeconds)
    } else if config.backgroundPollingMinutes > 0 {
      interval = TimeInterval(config.backgroundPollingMinutes * 60)
    } else {
      return
    }
    let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
      Task { @MainActor in
        // Skip the tick rather than pile up behind a slow refresh
        guard let self, !self.isLoading else { return }
        self.reloadConfigIfChanged()
        self.requestRefresh()
      }
    }
    // .common so ticks still fire while a menu (e.g. the org picker) is open
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func stopPolling() {
    timer?.invalidate()
    timer = nil
  }

  func switchSource(_ source: OrgSource?) {
    guard source != selectedSource else { return }
    selectedSource = source
    clearData()
    requestRefresh()
  }

  private func clearData() {
    repoGroups = []
    pullRequests = [:]
    mostRecentRepoId = nil
    overallStatus = .unknown
  }

  func requestRefresh() {
    cancelRefresh()
    let generation = refreshGeneration
    isLoading = true
    refreshTask = Task { [weak self] in
      await self?.refresh(generation: generation)
    }
  }

  private func cancelRefresh() {
    refreshTask?.cancel()
    refreshTask = nil
    refreshGeneration += 1
    isLoading = false
  }

  private func isCurrent(_ generation: Int) -> Bool {
    !Task.isCancelled && generation == refreshGeneration
  }

  private func refresh(generation: Int) async {
    defer {
      if generation == refreshGeneration {
        isLoading = false
        refreshTask = nil
      }
    }

    if config.includePersonal && config.username.isEmpty {
      if let login = try? await GitHubService.currentUsername(), !login.isEmpty {
        guard isCurrent(generation) else { return }
        resolvedUsername = login
        config.username = login
      }
    }

    if selectedSource == nil {
      selectedSource = availableSources.first
    }
    guard let source = selectedSource else {
      lastError = combinedError(
        "No sources configured. Add \"orgs\" to \(AppConfig.configFile.path), "
        + "or make sure `gh auth status` works so your personal repos can be found."
      )
      return
    }

    async let runsResult = GitHubService.fetchRunsForSource(source, config: config)
    async let prsResult = GitHubService.fetchPRsForSource(source, config: config)
    let (runs, prs) = await (runsResult, prsResult)

    guard isCurrent(generation), source == selectedSource else { return }

    lastRefresh = Date()
    lastError = combinedError((runs.error ?? prs.error)?.localizedDescription)

    // Build Repo → Workflow → Runs hierarchy
    var repos: [RepoGroup] = []
    for (repo, repoRuns) in runs.byRepo {
      let shortName = repo.components(separatedBy: "/").last ?? repo
      let byWorkflow = Dictionary(grouping: repoRuns, by: \.workflowName)

      let workflows = byWorkflow.map { (name, wfRuns) in
        WorkflowGroup(
          id: "\(repo)::\(name)",
          workflowName: name,
          runs: wfRuns.map { run in
            RunViewModel(
              id: run.databaseId,
              branch: run.headBranch,
              status: parseRunStatus(status: run.status, conclusion: run.conclusion),
              duration: formatDuration(from: run.startedAt, to: run.updatedAt),
              updatedAt: run.updatedAt,
              url: URL(string: run.url)
            )
          },
          stats: computeWorkflowStats(runs: wfRuns)
        )
      }.sorted { $0.workflowName < $1.workflowName }

      let latestDate = repoRuns.map(\.updatedAt).max() ?? .distantPast

      if !workflows.isEmpty {
        repos.append(RepoGroup(
          id: repo, repo: repo, shortName: shortName,
          workflows: workflows, mostRecentDate: latestDate
        ))
      }
    }

    // Sort by most recent activity first
    self.repoGroups = repos.sorted { $0.mostRecentDate > $1.mostRecentDate }
    self.mostRecentRepoId = self.repoGroups.first?.id

    // Build PR view models grouped by repo
    var prsByRepo: [String: [PRViewModel]] = [:]
    for (repo, repoPRs) in prs.byRepo {
      prsByRepo[repo] = repoPRs.map { pr in
        PRViewModel(
          id: "\(repo)#\(pr.number)",
          number: pr.number,
          title: pr.title,
          repo: repo,
          branch: pr.headRefName,
          reviewStatus: parseReviewStatus(pr.reviewDecision),
          checksStatus: checksOverallStatus(pr.statusCheckRollup),
          updatedAt: pr.updatedAt,
          url: URL(string: pr.url)
        )
      }
    }
    self.pullRequests = prsByRepo

    let latestRuns = repoGroups.flatMap(\.workflows).compactMap { workflow in
      workflow.runs.max { $0.updatedAt < $1.updatedAt }?.status
    }
    let prChecks = prsByRepo.values.joined().map(\.checksStatus)
    overallStatus = combinedStatus(latestRuns + prChecks)
  }

  /// Config problems stay visible alongside any fetch error.
  private func combinedError(_ fetchError: String?) -> String? {
    let parts = [configError, fetchError].compactMap { $0 }
    return parts.isEmpty ? nil : parts.joined(separator: "\n")
  }
}
