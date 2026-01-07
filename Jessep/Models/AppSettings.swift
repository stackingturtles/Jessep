import SwiftUI
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("launchAtLogin") var launchAtLogin = false {
        didSet {
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    @AppStorage("refreshInterval") var refreshInterval = 300 // 5 minutes

    @AppStorage("menuBarStyle") var menuBarStyle = "icon"

    @AppStorage("showNotifications") var showNotifications = true

    @AppStorage("warningThreshold") var warningThreshold = 65

    @AppStorage("alertOnReset") var alertOnReset = true

    private init() {
        // Sync launch at login state on init
        if LaunchAtLoginManager.isEnabled != launchAtLogin {
            launchAtLogin = LaunchAtLoginManager.isEnabled
        }
    }
}

enum MenuBarStyle: String, CaseIterable, Identifiable {
    case icon = "icon"
    case percentage = "percentage"
    case dynamic = "dynamic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .icon: return "Icon only"
        case .percentage: return "Show percentage"
        case .dynamic: return "Colour by usage"
        }
    }

    var description: String {
        switch self {
        case .icon: return "Static chart icon"
        case .percentage: return "Shows highest usage %"
        case .dynamic: return "Icon colour changes with usage"
        }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case tenMinutes = 600

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .twoMinutes: return "2 minutes"
        case .fiveMinutes: return "5 minutes"
        case .tenMinutes: return "10 minutes"
        }
    }
}
