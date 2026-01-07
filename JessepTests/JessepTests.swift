import XCTest
@testable import Jessep

final class JessepTests: XCTestCase {

    // MARK: - UsageData Tests

    func testUsageResponse_decodesValidJSON() throws {
        let json = """
        {
            "five_hour": {
                "utilization": 1.0,
                "resets_at": "2026-01-07T08:00:00.000000+00:00"
            },
            "seven_day": {
                "utilization": 60.0,
                "resets_at": "2026-01-09T07:59:00.000000+00:00"
            },
            "seven_day_oauth_apps": null,
            "seven_day_opus": {
                "utilization": 0.0,
                "resets_at": null
            },
            "sonnet_only": {
                "utilization": 73.0,
                "resets_at": "2026-01-09T09:59:00.000000+00:00"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.fiveHour?.utilization, 1.0)
        XCTAssertNotNil(response.fiveHour?.resetsAt)
        XCTAssertEqual(response.sevenDay?.utilization, 60.0)
        XCTAssertNil(response.sevenDayOauthApps)
        XCTAssertEqual(response.sevenDayOpus?.utilization, 0.0)
        XCTAssertNil(response.sevenDayOpus?.resetsAt)
        XCTAssertEqual(response.sonnetOnly?.utilization, 73.0)
    }

    func testUsageResponse_handlesMissingFields() throws {
        let json = """
        {
            "five_hour": {
                "utilization": 50.0,
                "resets_at": "2026-01-07T08:00:00.000000+00:00"
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertNotNil(response.fiveHour)
        XCTAssertNil(response.sevenDay)
        XCTAssertNil(response.sonnetOnly)
    }

    func testUsageResponse_maxUtilization() throws {
        let json = """
        {
            "five_hour": {"utilization": 25.0, "resets_at": null},
            "seven_day": {"utilization": 60.0, "resets_at": null},
            "sonnet_only": {"utilization": 73.0, "resets_at": null}
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(UsageResponse.self, from: json)

        XCTAssertEqual(response.maxUtilization, 73.0)
    }

    func testUsageLimit_isAtLimit() {
        let atLimit = UsageLimit(utilization: 100.0, resetsAt: nil)
        let overLimit = UsageLimit(utilization: 105.0, resetsAt: nil)
        let underLimit = UsageLimit(utilization: 99.9, resetsAt: nil)

        XCTAssertTrue(atLimit.isAtLimit)
        XCTAssertTrue(overLimit.isAtLimit)
        XCTAssertFalse(underLimit.isAtLimit)
    }

    // MARK: - DateFormatters Tests

    func testFormatTimeRemaining_lessThanHour() {
        let now = Date()
        let future = now.addingTimeInterval(45 * 60) // 45 minutes

        let result = DateFormatters.formatTimeRemaining(until: future)

        XCTAssertTrue(result.contains("45 min"))
        XCTAssertTrue(result.hasPrefix("Resets in"))
    }

    func testFormatTimeRemaining_lessThanDay() {
        let now = Date()
        let future = now.addingTimeInterval(3 * 60 * 60 + 52 * 60) // 3 hr 52 min

        let result = DateFormatters.formatTimeRemaining(until: future)

        XCTAssertTrue(result.contains("3 hr"))
        XCTAssertTrue(result.contains("52 min"))
    }

    func testFormatTimeRemaining_moreThanDay() {
        let now = Date()
        let future = now.addingTimeInterval(30 * 60 * 60) // 30 hours

        let result = DateFormatters.formatTimeRemaining(until: future)

        // Should show day name like "Resets Thu 8:59 AM"
        XCTAssertTrue(result.hasPrefix("Resets"))
        XCTAssertFalse(result.contains("hr"))
    }

    func testFormatTimeRemaining_past() {
        let now = Date()
        let past = now.addingTimeInterval(-60) // 1 minute ago

        let result = DateFormatters.formatTimeRemaining(until: past)

        XCTAssertEqual(result, "Resetting...")
    }

    func testFormatRelativeTime_justNow() {
        let now = Date()

        let result = DateFormatters.formatRelativeTime(from: now)

        XCTAssertEqual(result, "Just now")
    }

    func testFormatRelativeTime_minutes() {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)

        let result = DateFormatters.formatRelativeTime(from: fiveMinutesAgo)

        XCTAssertEqual(result, "5 min ago")
    }

    func testFormatRelativeTime_hours() {
        let twoHoursAgo = Date().addingTimeInterval(-2 * 60 * 60)

        let result = DateFormatters.formatRelativeTime(from: twoHoursAgo)

        XCTAssertEqual(result, "2 hr ago")
    }

    func testParseISO8601_withFractionalSeconds() {
        let dateString = "2026-01-07T08:00:00.000000+00:00"

        let date = DateFormatters.parseISO8601(dateString)

        XCTAssertNotNil(date)
    }

    func testParseISO8601_withoutFractionalSeconds() {
        let dateString = "2026-01-07T08:00:00+00:00"

        let date = DateFormatters.parseISO8601(dateString)

        XCTAssertNotNil(date)
    }

    // MARK: - UsageHistory Tests

    func testUsageHistory_predictsTimeToLimit() {
        let history = UsageHistory()
        history.clear()

        // Add data points simulating increasing usage
        // This is a simplified test - in reality we'd need to wait between additions
        // For now, we just verify the structure works

        XCTAssertNil(history.predictTimeToLimit(for: "session"))
    }

    // MARK: - MenuBarStyle Tests

    func testMenuBarStyle_allCases() {
        XCTAssertEqual(MenuBarStyle.allCases.count, 3)
        XCTAssertEqual(MenuBarStyle.icon.rawValue, "icon")
        XCTAssertEqual(MenuBarStyle.percentage.rawValue, "percentage")
        XCTAssertEqual(MenuBarStyle.dynamic.rawValue, "dynamic")
    }

    func testMenuBarStyle_displayNames() {
        XCTAssertEqual(MenuBarStyle.icon.displayName, "Icon only")
        XCTAssertEqual(MenuBarStyle.percentage.displayName, "Show percentage")
        XCTAssertEqual(MenuBarStyle.dynamic.displayName, "Colour by usage")
    }

    // MARK: - RefreshInterval Tests

    func testRefreshInterval_allCases() {
        XCTAssertEqual(RefreshInterval.allCases.count, 4)
        XCTAssertEqual(RefreshInterval.oneMinute.rawValue, 60)
        XCTAssertEqual(RefreshInterval.twoMinutes.rawValue, 120)
        XCTAssertEqual(RefreshInterval.fiveMinutes.rawValue, 300)
        XCTAssertEqual(RefreshInterval.tenMinutes.rawValue, 600)
    }
}
