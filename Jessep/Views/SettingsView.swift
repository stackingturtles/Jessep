import SwiftUI
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            NotificationSettingsView()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AuthenticationSettingsView()
                .tabItem {
                    Label("Authentication", systemImage: "key")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 550)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)

                Picker("Refresh Interval", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval.rawValue)
                    }
                }

                Picker("Menu Bar Style", selection: $settings.menuBarStyle) {
                    ForEach(MenuBarStyle.allCases) { style in
                        VStack(alignment: .leading) {
                            Text(style.displayName)
                        }
                        .tag(style.rawValue)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Notification Settings

struct NotificationSettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var permissionGranted = false

    var body: some View {
        Form {
            Section {
                Toggle("Enable Notifications", isOn: $settings.showNotifications)

                if settings.showNotifications {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Warning Threshold")
                            Spacer()
                            Text("\(settings.warningThreshold)%")
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.warningThreshold) },
                                set: { settings.warningThreshold = Int($0) }
                            ),
                            in: 50...95,
                            step: 5
                        )
                        Text("Get notified when usage exceeds this threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Toggle("Alert When Limits Reset", isOn: $settings.alertOnReset)
                }
            }

            Section {
                HStack {
                    Text("Notification Permission")
                    Spacer()
                    if permissionGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Request Permission") {
                            Task {
                                permissionGranted = await NotificationService.shared.requestPermission()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            permissionGranted = settings.authorizationStatus == .authorized
        }
    }
}

// MARK: - Authentication Settings

struct AuthenticationSettingsView: View {
    @State private var tokenSource = KeychainService.tokenSource()
    @State private var showTokenEntry = false
    @State private var manualToken = ""
    @State private var saveError: String?
    @State private var showClearConfirmation = false
    @State private var isRefreshing = false
    @State private var refreshError: String?
    @State private var showRefreshSuccess = false

    var body: some View {
        Form {
            Section("Token Status") {
                HStack {
                    Text("Source")
                    Spacer()
                    switch tokenSource {
                    case .claudeCode:
                        Label("Claude Code", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    case .manual:
                        Label("Manual Entry", systemImage: "key.fill")
                            .foregroundColor(.blue)
                    case .none:
                        Label("Not Found", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }

                if tokenSource == .claudeCode {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: refreshTokenFromKeychain) {
                            HStack {
                                if isRefreshing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                }
                                Text("Refresh Token from Keychain")
                            }
                        }
                        .disabled(isRefreshing)

                        if let error = refreshError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        if showRefreshSuccess {
                            Text("Token refreshed successfully")
                                .font(.caption)
                                .foregroundColor(.green)
                        }

                        Text("This will prompt you to enter your macOS keychain password to re-authorise access to the Claude Code token.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Manual Token Entry") {
                if showTokenEntry {
                    VStack(alignment: .leading, spacing: 8) {
                        SecureField("Paste your token", text: $manualToken)
                            .textFieldStyle(.roundedBorder)

                        if let error = saveError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }

                        HStack {
                            Button("Cancel") {
                                showTokenEntry = false
                                manualToken = ""
                                saveError = nil
                            }

                            Button("Save Token") {
                                saveToken()
                            }
                            .disabled(manualToken.isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    Button("Enter Token Manually") {
                        showTokenEntry = true
                    }
                }

                if tokenSource == .manual {
                    Button("Clear Saved Token", role: .destructive) {
                        showClearConfirmation = true
                    }
                }

                DisclosureGroup("How to get your token") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. Open claude.ai in your browser")
                        Text("2. Open Developer Tools (Cmd+Option+I)")
                        Text("3. Go to Network tab")
                        Text("4. Filter by \"usage\"")
                        Text("5. Find request to /api/oauth/usage")
                        Text("6. Copy the Bearer token from Authorization header")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .confirmationDialog("Clear Token?", isPresented: $showClearConfirmation) {
            Button("Clear Token", role: .destructive) {
                clearToken()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove your manually entered token.")
        }
    }

    private func saveToken() {
        do {
            try KeychainService.saveManualToken(manualToken)
            tokenSource = KeychainService.tokenSource()
            showTokenEntry = false
            manualToken = ""
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func clearToken() {
        try? KeychainService.deleteManualToken()
        tokenSource = KeychainService.tokenSource()
    }

    private func refreshTokenFromKeychain() {
        isRefreshing = true
        refreshError = nil
        showRefreshSuccess = false

        Task {
            do {
                // Force keychain authentication
                _ = try KeychainService.refreshClaudeCodeToken()

                // Update token source
                await MainActor.run {
                    tokenSource = KeychainService.tokenSource()
                    showRefreshSuccess = true
                    isRefreshing = false
                }

                // Auto-hide success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showRefreshSuccess = false
                }
            } catch {
                await MainActor.run {
                    refreshError = error.localizedDescription
                    isRefreshing = false
                }
            }
        }
    }
}

// MARK: - About Settings

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            // App icon
            if let image = NSImage(named: "AppIcon") {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 120, height: 120)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            } else {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.claudeProgressBar)
            }

            Text(AppInfo.name)
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(AppInfo.fullVersion)")
                .foregroundColor(.secondary)

            // Quote section
            VStack(spacing: 8) {
                Text("\"Son, we live in a world that has tokens, and those tokens have to be guarded by men with guns.\"")
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .italic()

                Text("— Lt. Colonel Jessep")
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)

            Text("A macOS menu bar app for monitoring your Claude Max plan usage limits.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            HStack(spacing: 16) {
                Link(destination: AppLinks.github) {
                    Label("GitHub", systemImage: "link")
                }

                Link(destination: AppLinks.claudeAI) {
                    Label("Claude.ai", systemImage: "globe")
                }
            }

            Spacer()

            Text("Made with care for Claude users")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(AppSettings.shared)
}
