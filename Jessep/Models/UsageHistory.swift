import Foundation

struct UsageDataPoint: Codable, Equatable {
    let timestamp: Date
    let utilization: Double
    let category: String
}

class UsageHistory: ObservableObject {
    private var dataPoints: [UsageDataPoint] = []
    private let maxPoints = 100  // Keep last ~8 hours at 5min intervals
    private let fileURL: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("Jessep", isDirectory: true)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        fileURL = appFolder.appendingPathComponent("usage_history.json")

        loadHistory()
    }

    func add(_ usage: UsageResponse) {
        let now = Date()

        if let fiveHour = usage.fiveHour {
            addPoint(UsageDataPoint(timestamp: now, utilization: fiveHour.utilization, category: "session"))
        }
        if let sevenDay = usage.sevenDay {
            addPoint(UsageDataPoint(timestamp: now, utilization: sevenDay.utilization, category: "weekly"))
        }
        if let sonnet = usage.sonnetOnly {
            addPoint(UsageDataPoint(timestamp: now, utilization: sonnet.utilization, category: "sonnet"))
        }

        pruneOldData()
        saveHistory()
    }

    private func addPoint(_ point: UsageDataPoint) {
        dataPoints.append(point)
    }

    private func pruneOldData() {
        // Keep only data from last 8 hours
        let cutoff = Date().addingTimeInterval(-8 * 60 * 60)
        dataPoints = dataPoints.filter { $0.timestamp > cutoff }

        // Also limit to maxPoints
        if dataPoints.count > maxPoints * 3 {  // 3 categories
            let sortedPoints = dataPoints.sorted { $0.timestamp > $1.timestamp }
            dataPoints = Array(sortedPoints.prefix(maxPoints * 3))
        }
    }

    func predictTimeToLimit(for category: String) -> TimeInterval? {
        let categoryPoints = dataPoints
            .filter { $0.category == category }
            .sorted { $0.timestamp < $1.timestamp }

        guard categoryPoints.count >= 2 else { return nil }

        // Use recent points for rate calculation
        let recent = Array(categoryPoints.suffix(10))
        guard let first = recent.first, let last = recent.last else { return nil }

        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        let usageDelta = last.utilization - first.utilization

        // Need positive time delta and usage increase
        guard timeDelta > 60, usageDelta > 0 else { return nil }

        let ratePerSecond = usageDelta / timeDelta
        let remainingUsage = 100.0 - last.utilization

        guard remainingUsage > 0 else { return nil }

        return remainingUsage / ratePerSecond
    }

    func formattedPrediction(for category: String) -> String? {
        guard let timeToLimit = predictTimeToLimit(for: category) else {
            return nil
        }

        // Cap at 24 hours
        if timeToLimit > 24 * 60 * 60 {
            return "More than 24 hours"
        }

        let hours = Int(timeToLimit) / 3600
        let minutes = (Int(timeToLimit) % 3600) / 60

        if hours > 0 {
            return "Limit in \(hours) hr \(minutes) min"
        } else if minutes > 0 {
            return "Limit in \(minutes) min"
        } else {
            return "Limit imminent"
        }
    }

    func currentRate(for category: String) -> Double? {
        let categoryPoints = dataPoints
            .filter { $0.category == category }
            .sorted { $0.timestamp < $1.timestamp }

        guard categoryPoints.count >= 2 else { return nil }

        let recent = Array(categoryPoints.suffix(10))
        guard let first = recent.first, let last = recent.last else { return nil }

        let timeDelta = last.timestamp.timeIntervalSince(first.timestamp)
        let usageDelta = last.utilization - first.utilization

        guard timeDelta > 60 else { return nil }

        // Return rate per hour
        return (usageDelta / timeDelta) * 3600
    }

    // MARK: - Persistence

    private func loadHistory() {
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            dataPoints = try decoder.decode([UsageDataPoint].self, from: data)
        } catch {
            dataPoints = []
        }
    }

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(dataPoints)
            try data.write(to: fileURL)
        } catch {
            print("Failed to save usage history: \(error)")
        }
    }

    func clear() {
        dataPoints = []
        try? FileManager.default.removeItem(at: fileURL)
    }
}
