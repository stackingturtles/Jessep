import SwiftUI

struct UsagePopoverView: View {
    @ObservedObject var viewModel: UsageViewModel
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Color.claudeDivider)

            if viewModel.hasToken {
                if viewModel.isLoading && viewModel.usageData == nil {
                    loadingView
                } else if let error = viewModel.error, viewModel.usageData == nil {
                    ErrorView(error: error) {
                        Task { await viewModel.refresh() }
                    }
                } else if let usage = viewModel.usageData {
                    usageContentView(usage)
                } else {
                    noDataView
                }
            } else {
                noTokenView
            }

            Divider()
                .background(Color.claudeDivider)

            // Footer
            footerView
        }
        .frame(width: 320)
        .background(Color.claudeBackground)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Plan usage limits")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.claudeTextPrimary)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            if viewModel.isOffline {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 11))
                    .foregroundColor(.claudeWarning)
                    .help("Showing cached data")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Usage Content

    private func usageContentView(_ usage: UsageResponse) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                // Current Session (5-hour)
                if let fiveHour = usage.fiveHour {
                    sectionView(title: "Current session") {
                        UsageProgressBar(
                            title: "Session limit",
                            subtitle: DateFormatters.formatTimeRemaining(from: fiveHour.resetsAt),
                            percentage: fiveHour.utilization,
                            prediction: viewModel.prediction(for: "session")
                        )
                    }
                }

                // Weekly Limits
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Weekly limits")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.claudeTextSecondary)

                        Spacer()

                        Link(destination: AppLinks.usageDocs) {
                            HStack(spacing: 2) {
                                Text("Learn more")
                                    .font(.system(size: 10))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.claudeProgressBar)
                        }
                    }

                    if let sevenDay = usage.sevenDay {
                        UsageProgressBar(
                            title: "All models",
                            subtitle: DateFormatters.formatTimeRemaining(from: sevenDay.resetsAt),
                            percentage: sevenDay.utilization,
                            prediction: viewModel.prediction(for: "weekly")
                        )
                    }

                    if let sonnetOnly = usage.sonnetOnly {
                        UsageProgressBar(
                            title: "Sonnet only",
                            subtitle: DateFormatters.formatTimeRemaining(from: sonnetOnly.resetsAt),
                            percentage: sonnetOnly.utilization,
                            prediction: viewModel.prediction(for: "sonnet"),
                            showInfoButton: true,
                            onInfoTap: {
                                NSWorkspace.shared.open(AppLinks.usageDocs)
                            }
                        )
                    }

                    // Opus limit (if present)
                    if let opus = usage.sevenDayOpus, opus.utilization > 0 {
                        UsageProgressBar(
                            title: "Opus only",
                            subtitle: DateFormatters.formatTimeRemaining(from: opus.resetsAt),
                            percentage: opus.utilization
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
        }
    }

    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.claudeTextSecondary)

            content()
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading usage data...")
                .font(.system(size: 12))
                .foregroundColor(.claudeTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - No Token View

    private var noTokenView: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 32))
                .foregroundColor(.claudeTextSecondary)

            Text("Authentication Required")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.claudeTextPrimary)

            Text("Install Claude Code and log in, or enter your token manually in Settings.")
                .font(.system(size: 12))
                .foregroundColor(.claudeTextSecondary)
                .multilineTextAlignment(.center)

            OpenSettingsButton {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }

    // MARK: - No Data View

    private var noDataView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 32))
                .foregroundColor(.claudeTextSecondary)

            Text("No usage data available")
                .font(.system(size: 12))
                .foregroundColor(.claudeTextSecondary)

            Button("Refresh") {
                Task { await viewModel.refresh() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            // Refresh status
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                Text(viewModel.lastRefreshFormatted)
                    .font(.system(size: 10))
            }
            .foregroundColor(.claudeTextSecondary)

            Spacer()

            // Settings button
            OpenSettingsButton {
                HStack(spacing: 4) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                    Text("Settings")
                        .font(.system(size: 11))
                }
                .foregroundColor(.claudeTextSecondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

}

// MARK: - Open Settings Button

struct OpenSettingsButton<Label: View>: View {
    let label: Label

    init(@ViewBuilder label: () -> Label) {
        self.label = label()
    }

    var body: some View {
        Button(action: openSettings) {
            label
        }
    }

    private func openSettings() {
        // Post notification - AppDelegate will handle opening the window
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = UsageViewModel()
    return UsagePopoverView(viewModel: viewModel)
        .environmentObject(AppSettings.shared)
}
