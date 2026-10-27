import Foundation
import ServiceManagement

/// Open-at-login via SMAppService. Only works when running from the bundled GHBar.app.
enum LoginItem {
  static let unregisterArgument = "--unregister-login-item"

  static var isAvailable: Bool {
    Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
  }

  static var isEnabled: Bool {
    isAvailable && SMAppService.mainApp.status == .enabled
  }

  static func setEnabled(_ enabled: Bool) throws {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }

  /// Registers once on first launch so a fresh install opens at login, as the
  /// old LaunchAgent did, while respecting a later opt-out from the popover.
  static func registerOnFirstLaunch() {
    let key = "didRegisterLoginItem"
    guard isAvailable, !UserDefaults.standard.bool(forKey: key) else { return }
    try? SMAppService.mainApp.register()
    UserDefaults.standard.set(true, forKey: key)
  }
}
