import SwiftUI

extension View {
  /// Pointing-hand cursor while hovered. Uses `set()` instead of push/pop so a row
  /// that disappears mid-hover (e.g. on refresh) can't leave the cursor stack unbalanced.
  func pointingHandCursor() -> some View {
    onHover { hovering in
      (hovering ? NSCursor.pointingHand : NSCursor.arrow).set()
    }
  }
}

func openInBrowser(_ url: URL?) {
  guard let url else { return }
  NSWorkspace.shared.open(url)
}

/// "3m ago" that keeps ticking between refreshes.
struct RelativeTimeText: View {
  let date: Date

  var body: some View {
    TimelineView(.periodic(from: .now, by: 30)) { context in
      Text(relativeTime(from: date, now: context.date))
    }
  }
}
