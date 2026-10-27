import SwiftUI

struct ActionsView: View {
  let repoGroups: [RepoGroup]
  let mostRecentRepoId: String?

  var body: some View {
    if repoGroups.isEmpty {
      emptyState
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          ForEach(repoGroups) { repo in
            RepoDisclosure(
              repo: repo,
              startsExpanded: repo.id == mostRecentRepoId
            )
          }
        }
        .padding(.vertical, 4)
      }
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      Spacer()
      Image(systemName: "tray")
        .font(.system(size: 28))
        .foregroundStyle(.tertiary)
      Text("No workflow runs found")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Repo disclosure (stateful, controls its own expansion)

private struct RepoDisclosure: View {
  let repo: RepoGroup
  let startsExpanded: Bool
  @State private var isExpanded: Bool = false

  init(repo: RepoGroup, startsExpanded: Bool) {
    self.repo = repo
    self.startsExpanded = startsExpanded
    self._isExpanded = State(initialValue: startsExpanded)
  }

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      ForEach(repo.workflows) { workflow in
        workflowSection(workflow: workflow)
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "folder.fill")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        Text(repo.shortName)
          .font(.system(size: 13, weight: .semibold))
        Spacer()
        repoStatusBadge
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 1)
  }

  private var repoStatusBadge: some View {
    let worst = combinedStatus(repo.workflows.flatMap { $0.runs }.map(\.status))
    return Image(systemName: worst.symbol)
      .font(.system(size: 12))
      .foregroundColor(worst.color)
  }

  private func workflowSection(workflow: WorkflowGroup) -> some View {
    DisclosureGroup {
      ForEach(workflow.runs) { run in
        runRow(run: run)
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "gearshape")
          .font(.system(size: 11))
          .foregroundStyle(.tertiary)
        Text(workflow.workflowName)
          .font(.system(size: 12, weight: .medium))
        Spacer()
        statsLabel(workflow.stats)
      }
    }
    .padding(.leading, 8)
    .padding(.vertical, 0)
  }

  private func statsLabel(_ stats: WorkflowStats) -> some View {
    HStack(spacing: 6) {
      if let rate = stats.successRate {
        Text("\(rate)%")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundColor(rate >= 80 ? .green : rate >= 50 ? .orange : .red)
      } else {
        Text("–")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .foregroundStyle(.tertiary)
      }

      HStack(spacing: 2) {
        Image(systemName: "clock")
          .font(.system(size: 10))
        Text(stats.avgDuration)
          .font(.system(size: 12, design: .monospaced))
      }
      .foregroundStyle(.tertiary)

      if stats.failCount > 0 {
        HStack(spacing: 2) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 10))
          Text("\(stats.failCount)")
            .font(.system(size: 12, design: .monospaced))
        }
        .foregroundColor(.red.opacity(0.8))
      }
    }
  }

  private func runRow(run: RunViewModel) -> some View {
    Button(action: { openInBrowser(run.url) }) {
      HStack(spacing: 6) {
        Image(systemName: run.status.symbol)
          .font(.system(size: 11))
          .foregroundColor(run.status.color)
        Text(run.branch)
          .font(.system(size: 11, design: .monospaced))
          .lineLimit(1)
        Spacer()
        Text(run.duration)
          .font(.system(size: 10, design: .monospaced))
          .foregroundStyle(.tertiary)
        RelativeTimeText(date: run.updatedAt)
          .font(.system(size: 10))
          .foregroundStyle(.quaternary)
      }
      .padding(.leading, 16)
      .padding(.vertical, 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .pointingHandCursor()
  }
}
