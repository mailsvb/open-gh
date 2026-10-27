import SwiftUI

struct ContentView: View {
  @ObservedObject var appState: AppState

  var body: some View {
    VStack(spacing: 0) {
      // Single-line header: [Actions | PRs]  ---  [org dropdown] [refresh]
      HStack(spacing: 8) {
        Picker("", selection: $appState.selectedTab) {
          ForEach(AppState.Tab.allCases, id: \.self) { tab in
            Text(tab.rawValue).tag(tab)
          }
        }
        .pickerStyle(.segmented)
        .frame(width: 150)

        Spacer()

        if !appState.availableSources.isEmpty {
          // Custom binding so only user picks trigger a source switch
          Picker("", selection: Binding(
            get: { appState.selectedSource },
            set: { appState.switchSource($0) }
          )) {
            ForEach(appState.availableSources) { source in
              Text(source.displayName).tag(Optional(source))
            }
          }
          .labelsHidden()
          .pickerStyle(.menu)
          .frame(maxWidth: 160)
        }

        if appState.isLoading {
          ProgressView()
            .controlSize(.small)
        }

        Button(action: { appState.requestRefresh() }) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 11))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)

      Divider()

      if let error = appState.lastError {
        errorBanner(error)
        Divider()
      }

      // Content
      switch appState.selectedTab {
      case .actions:
        ActionsView(repoGroups: appState.repoGroups, mostRecentRepoId: appState.mostRecentRepoId)
      case .prs:
        PRsView(prsByRepo: appState.pullRequests)
      }

      // Footer
      Divider()
      HStack {
        if let last = appState.lastRefresh {
          Text("Updated at \(formatTime(last))")
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button("Quit") { NSApp.terminate(nil) }
          .buttonStyle(.plain)
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
    }
  }

  private func errorBanner(_ message: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 11))
        .foregroundColor(.orange)
      Text(message)
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(4)
        .textSelection(.enabled)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(Color.orange.opacity(0.08))
  }
}
