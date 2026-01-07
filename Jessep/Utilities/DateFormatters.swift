import Foundation

struct DateFormatters {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601FormatterNoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let dayTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE h:mm a"
        return formatter
    }()

    // MARK: - Parse ISO8601

    static func parseISO8601(_ string: String) -> Date? {
        // Try with fractional seconds first
        if let date = iso8601Formatter.date(from: string) {
            return date
        }
        // Fall back to without fractional seconds
        return iso8601FormatterNoFractional.date(from: string)
    }

    // MARK: - Format Time Remaining

    static func formatTimeRemaining(from isoString: String?) -> String {
        guard let isoString = isoString,
              let resetDate = parseISO8601(isoString) else {
            return "Unknown"
        }

        return formatTimeRemaining(until: resetDate)
    }

    static func formatTimeRemaining(until resetDate: Date) -> String {
        let now = Date()
        let interval = resetDate.timeIntervalSince(now)

        if interval <= 0 {
            return "Resetting..."
        }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours >= 24 {
            return "Resets \(dayTimeFormatter.string(from: resetDate))"
        } else if hours > 0 {
            return "Resets in \(hours) hr \(minutes) min"
        } else if minutes > 0 {
            return "Resets in \(minutes) min"
        } else {
            return "Resets in <1 min"
        }
    }

    // MARK: - Format Relative Time

    static func formatRelativeTime(from date: Date?) -> String {
        guard let date = date else { return "Never" }

        let interval = Date().timeIntervalSince(date)

        if interval < 0 {
            return "Just now"
        }

        let minutes = Int(interval) / 60

        if minutes < 1 {
            return "Just now"
        } else if minutes == 1 {
            return "1 min ago"
        } else if minutes < 60 {
            return "\(minutes) min ago"
        } else {
            let hours = minutes / 60
            if hours == 1 {
                return "1 hr ago"
            } else if hours < 24 {
                return "\(hours) hr ago"
            } else {
                let days = hours / 24
                if days == 1 {
                    return "1 day ago"
                } else {
                    return "\(days) days ago"
                }
            }
        }
    }

    // MARK: - Format Duration

    static func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 24 {
            return "More than 24 hours"
        } else if hours > 0 {
            return "\(hours) hr \(minutes) min"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "Less than 1 min"
        }
    }
}
