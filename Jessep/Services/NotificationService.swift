import UserNotifications
import Foundation

class NotificationService {
    static let shared = NotificationService()

    private var lastNotifiedState: [String: Double] = [:]
    private var scheduledResetNotifications: Set<String> = []

    private init() {}

    // MARK: - Permission

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Failed to request notification permission: \(error)")
            return false
        }
    }

    // MARK: - Threshold Notifications

    func checkAndNotify(usage: UsageResponse, threshold: Int) {
        guard AppSettings.shared.showNotifications else { return }

        let thresholdDouble = Double(threshold)

        if let fiveHour = usage.fiveHour {
            checkCategory("session", "Current Session", fiveHour.utilization, thresholdDouble)
        }
        if let sevenDay = usage.sevenDay {
            checkCategory("weekly", "Weekly Limit (All Models)", sevenDay.utilization, thresholdDouble)
        }
        if let sonnet = usage.sonnetOnly {
            checkCategory("sonnet", "Sonnet Only", sonnet.utilization, thresholdDouble)
        }
    }

    private func checkCategory(_ id: String, _ name: String, _ current: Double, _ threshold: Double) {
        let lastNotified = lastNotifiedState[id] ?? 0

        // Notify when crossing threshold (up only)
        if current >= threshold && lastNotified < threshold {
            sendNotification(
                title: "Claude Usage Warning",
                body: "\(name) usage at \(Int(current))%",
                identifier: "threshold-\(id)"
            )
        }

        // Notify when hitting 100%
        if current >= 100 && lastNotified < 100 {
            sendNotification(
                title: "Claude Limit Reached",
                body: "\(name) has reached 100%. Usage will reset soon.",
                identifier: "limit-\(id)"
            )
        }

        lastNotifiedState[id] = current
    }

    // MARK: - Reset Notifications

    func checkForReset(previous: UsageResponse?, current: UsageResponse) {
        guard AppSettings.shared.alertOnReset else { return }
        guard let previous = previous else { return }

        var resetCategories: [String] = []

        // Session reset (5-hour)
        if let prevSession = previous.fiveHour,
           let currSession = current.fiveHour,
           currSession.utilization < prevSession.utilization - 10,
           prevSession.utilization > 20 {
            resetCategories.append("Current Session")
            // Reset notification state
            lastNotifiedState["session"] = currSession.utilization
        }

        // Weekly reset
        if let prevWeekly = previous.sevenDay,
           let currWeekly = current.sevenDay,
           currWeekly.utilization < prevWeekly.utilization - 10,
           prevWeekly.utilization > 20 {
            resetCategories.append("Weekly (All Models)")
            lastNotifiedState["weekly"] = currWeekly.utilization
        }

        // Sonnet reset
        if let prevSonnet = previous.sonnetOnly,
           let currSonnet = current.sonnetOnly,
           currSonnet.utilization < prevSonnet.utilization - 10,
           prevSonnet.utilization > 20 {
            resetCategories.append("Sonnet Only")
            lastNotifiedState["sonnet"] = currSonnet.utilization
        }

        if !resetCategories.isEmpty {
            notifyReset(categories: resetCategories)
        }
    }

    private func notifyReset(categories: [String]) {
        let categoryList = categories.joined(separator: ", ")
        sendNotification(
            title: "Claude Limits Reset",
            body: "\(categoryList) has reset. You have fresh quota!",
            identifier: "reset-\(Date().timeIntervalSince1970)"
        )
    }

    func scheduleResetNotification(resetsAt: String, category: String) {
        guard AppSettings.shared.alertOnReset else { return }
        guard let resetDate = DateFormatters.parseISO8601(resetsAt) else { return }

        // Don't schedule if already past
        guard resetDate > Date() else { return }

        // Don't schedule duplicate
        let identifier = "scheduled-reset-\(category)"
        guard !scheduledResetNotifications.contains(identifier) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Claude Limit Reset"
        content.body = "\(category) has reset. You have fresh quota!"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: resetDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if error == nil {
                self?.scheduledResetNotifications.insert(identifier)
            }
        }
    }

    func cancelScheduledNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        scheduledResetNotifications.removeAll()
    }

    // MARK: - Send Notification

    private func sendNotification(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    // MARK: - Token Error Notification

    func notifyTokenError() {
        guard AppSettings.shared.showNotifications else { return }

        sendNotification(
            title: "Claude Usage - Authentication Required",
            body: "Please check your Claude Code login or enter a token manually.",
            identifier: "token-error"
        )
    }
}
