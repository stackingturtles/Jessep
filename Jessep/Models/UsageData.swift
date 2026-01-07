import Foundation

struct UsageResponse: Codable, Equatable {
    let fiveHour: UsageLimit?
    let sevenDay: UsageLimit?
    let sevenDayOauthApps: UsageLimit?
    let sevenDayOpus: UsageLimit?
    let sonnetOnly: UsageLimit?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sonnetOnly = "seven_day_sonnet"
    }
}

struct UsageLimit: Codable, Equatable {
    let utilization: Double
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

// MARK: - Convenience Extensions

extension UsageLimit {
    var resetsAtDate: Date? {
        guard let resetsAt = resetsAt else { return nil }
        return DateFormatters.parseISO8601(resetsAt)
    }

    var utilisationPercentage: Int {
        Int(min(utilization, 100))
    }

    var isAtLimit: Bool {
        utilization >= 100
    }
}

extension UsageResponse {
    /// Returns the highest utilization across all limits
    var maxUtilization: Double {
        [fiveHour?.utilization, sevenDay?.utilization, sonnetOnly?.utilization]
            .compactMap { $0 }
            .max() ?? 0
    }

    /// Check if any limit is at or above the given threshold
    func hasLimitAbove(_ threshold: Double) -> Bool {
        [fiveHour?.utilization, sevenDay?.utilization, sonnetOnly?.utilization]
            .compactMap { $0 }
            .contains { $0 >= threshold }
    }
}
