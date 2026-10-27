import AppKit

// Used by uninstall.sh to remove the login item before deleting the app
if CommandLine.arguments.contains(LoginItem.unregisterArgument) {
  try? LoginItem.setEnabled(false)
  exit(0)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // No dock icon

let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
