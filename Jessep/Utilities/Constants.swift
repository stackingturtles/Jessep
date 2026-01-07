import SwiftUI

// MARK: - API Constants

enum APIConstants {
    static let usageEndpoint = "https://api.anthropic.com/api/oauth/usage"
    static let betaHeader = "oauth-2025-04-20"
    static let userAgent = "Jessep/1.0"
}

// MARK: - Colour Palette

extension Color {
    // Background colours
    static let claudeBackground = Color(red: 0.13, green: 0.13, blue: 0.14)           // #212122
    static let claudeCardBackground = Color(red: 0.16, green: 0.16, blue: 0.17)       // #292929

    // Progress bar colours
    static let claudeProgressBar = Color(red: 0.33, green: 0.56, blue: 0.85)          // #548FD9
    static let claudeProgressTrack = Color(red: 0.25, green: 0.25, blue: 0.26)        // #404042

    // Text colours
    static let claudeTextPrimary = Color.white
    static let claudeTextSecondary = Color(white: 0.6)

    // Divider
    static let claudeDivider = Color(red: 0.25, green: 0.25, blue: 0.25)              // #404040

    // Status colours
    static let claudeSuccess = Color(red: 0.30, green: 0.69, blue: 0.31)              // #4CAF50
    static let claudeWarning = Color(red: 1.0, green: 0.76, blue: 0.03)               // #FFC107
    static let claudeError = Color(red: 0.96, green: 0.26, blue: 0.21)                // #F44336
}

// MARK: - App Information

enum AppInfo {
    static let name = "Jessep"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.stackingturtles.Jessep"

    static var fullVersion: String {
        "\(version) (\(build))"
    }
}

// MARK: - Links

enum AppLinks {
    static let usageDocs = URL(string: "https://support.claude.com/en/articles/11647753-understanding-usage-and-length-limits")!
    static let claudeAI = URL(string: "https://claude.ai")!
    static let github = URL(string: "https://github.com/stackingturtles/jessep")!
}
