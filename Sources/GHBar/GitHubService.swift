import Foundation

struct GHError: LocalizedError {
  let message: String
  var errorDescription: String? { message }
}

/// Results keyed by "owner/repo", plus the first error hit while fetching them.
struct SourceData<Value: Sendable>: Sendable {
  var byRepo: [String: [Value]] = [:]
  var error: Error?
}

enum GitHubService {

  // MARK: - Public API

  static func currentUsername() async throws -> String {
    try await gh(["api", "user", "--jq", ".login"])
  }

  static func fetchRepos(source: OrgSource, config: AppConfig) async throws -> [String] {
    var args = ["repo", "list", source.name, "--no-archived", "--limit", "\(config.maxReposPerOrg)"]
    if source.kind == .personal { args.append("--source") }
    args += ["--json", "nameWithOwner"]
    let repos = try await ghJSON(args, as: [GHRepo].self).map(\.nameWithOwner)

    // With --no-archived, gh returns [] instead of failing for an unknown owner,
    // so confirm the owner exists before reporting "no runs".
    if repos.isEmpty {
      do {
        _ = try await gh(["api", "users/\(source.name)", "--jq", ".login"])
      } catch is CancellationError {
        throw CancellationError()
      } catch {
        throw GHError(message: "GitHub owner \"\(source.name)\" not found or not visible: \(error.localizedDescription)")
      }
    }
    return repos
  }

  static func fetchRuns(repo: String, limit: Int) async throws -> [GHRun] {
    let fields = "databaseId,workflowName,status,conclusion,headBranch,startedAt,updatedAt,url"
    return try await ghJSON(["run", "list", "-R", repo, "--limit", "\(limit)", "--json", fields], as: [GHRun].self)
  }

  static func fetchPRs(repo: String) async throws -> [GHPullRequest] {
    let fields = "number,title,url,headRefName,reviewDecision,updatedAt,statusCheckRollup"
    return try await ghJSON(
      ["pr", "list", "-R", repo, "--author", "@me", "--state", "open", "--json", fields],
      as: [GHPullRequest].self
    )
  }

  /// Repos under `owner` where you have an open PR, via a single search call.
  static func reposWithMyOpenPRs(owner: String) async throws -> [String] {
    let hits = try await ghJSON(
      ["search", "prs", "--author", "@me", "--state", "open", "--owner", owner, "--limit", "100", "--json", "repository"],
      as: [GHSearchPR].self
    )
    return Set(hits.map(\.repository.nameWithOwner)).sorted()
  }

  // MARK: - Aggregate fetchers

  static func fetchRunsForSource(_ source: OrgSource, config: AppConfig) async -> SourceData<GHRun> {
    let repos: [String]
    do {
      repos = try await fetchRepos(source: source, config: config)
    } catch {
      return SourceData(error: error)
    }

    // First pass: small fetch for all repos to find most recently active
    var result = await withThrottledTasks(inputs: repos, concurrency: config.maxConcurrency) { repo in
      try await fetchRuns(repo: repo, limit: config.runsPerRepo)
    }

    // Find the most recently updated repo
    let activeRepo = result.byRepo
      .max { ($0.value.first?.updatedAt ?? .distantPast) < ($1.value.first?.updatedAt ?? .distantPast) }?
      .key

    // Second pass: fetch more runs for the active repo
    if let activeRepo, config.activeRepoRunsLimit > config.runsPerRepo,
       let moreRuns = try? await fetchRuns(repo: activeRepo, limit: config.activeRepoRunsLimit),
       !moreRuns.isEmpty {
      result.byRepo[activeRepo] = moreRuns
    }

    return result
  }

  static func fetchPRsForSource(_ source: OrgSource, config: AppConfig) async -> SourceData<GHPullRequest> {
    let repos: [String]
    do {
      repos = try await reposWithMyOpenPRs(owner: source.name)
    } catch {
      return SourceData(error: error)
    }
    return await withThrottledTasks(inputs: repos, concurrency: config.maxConcurrency) { repo in
      try await fetchPRs(repo: repo)
    }
  }

  // MARK: - Shell helpers

  /// Known install locations first; otherwise let `env` search PATH.
  private static let ghExecutable: (url: URL, leadingArgs: [String]) = {
    let candidates = [
      "/opt/homebrew/bin/gh",
      "/usr/local/bin/gh",
      "/usr/bin/gh"
    ]
    for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
      return (URL(fileURLWithPath: path), [])
    }
    return (URL(fileURLWithPath: "/usr/bin/env"), ["gh"])
  }()

  /// Box for pipe output written on a background queue and read after the group finishes.
  private final class DataBox: @unchecked Sendable {
    var data = Data()
  }

  private static func gh(_ arguments: [String]) async throws -> String {
    try Task.checkCancellation()
    let process = Process()
    let output = try await withTaskCancellationHandler {
      try await run(process, arguments: arguments)
    } onCancel: {
      if process.isRunning { process.terminate() }
    }
    try Task.checkCancellation()
    return output
  }

  /// Runs gh without blocking Swift's cooperative thread pool: both pipes are drained
  /// concurrently on GCD threads (so neither can fill up and stall the child), and the
  /// continuation resumes once the process has exited and both pipes hit EOF.
  private static func run(_ process: Process, arguments: [String]) async throws -> String {
    try await withCheckedThrowingContinuation { continuation in
      let stdout = Pipe()
      let stderr = Pipe()
      process.executableURL = ghExecutable.url
      process.arguments = ghExecutable.leadingArgs + arguments
      process.standardOutput = stdout
      process.standardError = stderr
      // Apps launched from Finder or as a login item get a minimal PATH
      var environment = ProcessInfo.processInfo.environment
      environment["PATH"] = (["/opt/homebrew/bin", "/usr/local/bin"] + [environment["PATH"] ?? "/usr/bin:/bin"])
        .joined(separator: ":")
      process.environment = environment

      let group = DispatchGroup()
      group.enter()
      process.terminationHandler = { _ in group.leave() }

      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
        return
      }

      let out = DataBox()
      let err = DataBox()
      DispatchQueue.global().async(group: group) { out.data = stdout.fileHandleForReading.readDataToEndOfFile() }
      DispatchQueue.global().async(group: group) { err.data = stderr.fileHandleForReading.readDataToEndOfFile() }

      group.notify(queue: .global()) {
        if process.terminationStatus == 0 {
          let text = String(decoding: out.data, as: UTF8.self)
          continuation.resume(returning: text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
          var message = String(decoding: err.data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
          if message.isEmpty { message = "gh exited with status \(process.terminationStatus)" }
          continuation.resume(throwing: GHError(message: message))
        }
      }
    }
  }

  private static func ghJSON<T: Decodable>(_ arguments: [String], as type: T.Type) async throws -> T {
    let output = try await gh(arguments)
    guard !output.isEmpty else {
      throw GHError(message: "gh returned no output for: gh \(arguments.joined(separator: " "))")
    }
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: Data(output.utf8))
  }

  // MARK: - Concurrency helper

  /// Runs `operation` for each repo with at most `concurrency` in flight. Repos with
  /// no values are dropped; the first error is kept so the UI can report it.
  private static func withThrottledTasks<Value: Sendable>(
    inputs: [String],
    concurrency: Int,
    operation: @Sendable @escaping (String) async throws -> [Value]
  ) async -> SourceData<Value> {
    var result = SourceData<Value>()

    await withTaskGroup(of: (String, Result<[Value], Error>).self) { group in
      var index = 0

      func collect(_ repo: String, _ outcome: Result<[Value], Error>) {
        switch outcome {
        case .success(let values) where !values.isEmpty:
          result.byRepo[repo] = values
        case .failure(let error) where result.error == nil:
          result.error = error
        default:
          break
        }
      }

      while index < inputs.count {
        if index >= concurrency, let (repo, outcome) = await group.next() {
          collect(repo, outcome)
        }
        let repo = inputs[index]
        group.addTask {
          do { return (repo, .success(try await operation(repo))) }
          catch { return (repo, .failure(error)) }
        }
        index += 1
      }

      for await (repo, outcome) in group {
        collect(repo, outcome)
      }
    }

    return result
  }
}
