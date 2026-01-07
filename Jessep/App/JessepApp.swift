import SwiftUI

@main
struct JessepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings scene for Cmd+, keyboard shortcut (if app menu is available)
        Settings {
            SettingsView()
                .environmentObject(AppSettings.shared)
        }
    }
}
