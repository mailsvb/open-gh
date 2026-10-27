import AppKit
import Combine
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
  private var statusItem: NSStatusItem!
  private var popover: NSPopover!
  private let appState = AppState()
  private var statusObserver: AnyCancellable?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    popover = NSPopover()
    popover.contentSize = NSSize(width: 420, height: 520)
    popover.behavior = .transient
    popover.delegate = self
    popover.contentViewController = NSHostingController(
      rootView: ContentView(appState: appState)
    )

    if let button = statusItem.button {
      button.image = StatusIcon.make(badge: nil)
      button.action = #selector(togglePopover)
      button.target = self
    }

    statusObserver = appState.$overallStatus
      .removeDuplicates()
      .sink { [weak self] status in
        self?.statusItem.button?.image = StatusIcon.make(badge: Self.badgeColor(for: status))
      }

    LoginItem.registerOnFirstLaunch()
    appState.start()
  }

  private static func badgeColor(for status: RunStatus) -> NSColor? {
    switch status {
    case .failure:             return .systemRed
    case .inProgress, .queued: return .systemOrange
    default:                   return nil
    }
  }

  @objc private func togglePopover() {
    guard let button = statusItem.button else { return }
    if popover.isShown {
      popover.performClose(nil)
    } else {
      popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
      NSApp.activate()
      appState.popoverOpened()
    }
  }

  // NSPopoverDelegate — handles both manual close and click-away dismiss
  nonisolated func popoverDidClose(_ notification: Notification) {
    Task { @MainActor in
      appState.popoverClosed()
    }
  }
}
