import SwiftUI
import Combine

@MainActor
class UsageViewModel: ObservableObject {
    @Published var usageData: UsageResponse?
    @Published var lastRefresh: Date?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var isOffline = false

    private var refreshTask: Task<Void, Never>?
    private var previousUsageData: UsageResponse?
    private let api: ClaudeAPIService
    private let cache: UsageCache
    private let history: UsageHistory
    private let retryHandler: RetryHandler

    init(api: ClaudeAPIService = ClaudeAPIService()) {
        self.api = api
        self.cache = UsageCache()
        self.history = UsageHistory()
        self.retryHandler = RetryHandler()
        loadCachedData()
    }

    func refresh() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        do {
            let newData = try await retryHandler.withRetry {
                try await self.api.fetchUsage()
            }

            // Check for resets before updating
            NotificationService.shared.checkForReset(previous: previousUsageData, current: newData)

            // Check thresholds and send notifications
            NotificationService.shared.checkAndNotify(
                usage: newData,
                threshold: AppSettings.shared.warningThreshold
            )

            previousUsageData = usageData
            usageData = newData
            lastRefresh = Date()
            isOffline = false

            // Update cache and history
            cache.save(newData)
            history.add(newData)
        } catch {
            self.error = error
            isOffline = true
            // Keep showing cached data on error
        }

        isLoading = false
    }

    func startPolling(interval: TimeInterval = 300) {
        stopPolling()
        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func stopPolling() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private func loadCachedData() {
        if let cached = cache.load() {
            usageData = cached.data
            lastRefresh = cached.timestamp
            previousUsageData = cached.data

            // Check if cached data is stale
            let age = Date().timeIntervalSince(cached.timestamp)
            isOffline = age > 3600 // More than 1 hour old
        }
    }

    // MARK: - Predictions

    func prediction(for category: String) -> String? {
        history.formattedPrediction(for: category)
    }

    func rate(for category: String) -> Double? {
        history.currentRate(for: category)
    }

    // MARK: - Computed Properties

    var hasToken: Bool {
        KeychainService.tokenSource() != .none
    }

    var tokenSource: KeychainService.TokenSource {
        KeychainService.tokenSource()
    }

    var cacheAge: TimeInterval? {
        guard let lastRefresh = lastRefresh else { return nil }
        return Date().timeIntervalSince(lastRefresh)
    }

    var lastRefreshFormatted: String {
        DateFormatters.formatRelativeTime(from: lastRefresh)
    }
}
