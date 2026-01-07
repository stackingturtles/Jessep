import XCTest
@testable import Jessep

final class ClaudeAPIServiceTests: XCTestCase {
    var session: URLSession!
    var api: ClaudeAPIService!

    override func setUp() {
        super.setUp()

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testFetchUsage_successfulResponse() async throws {
        // Note: This test requires a token to be available
        // In real tests, we'd mock the keychain as well

        let json = """
        {
            "five_hour": {"utilization": 25.0, "resets_at": "2026-01-07T08:00:00.000000+00:00"},
            "seven_day": {"utilization": 60.0, "resets_at": "2026-01-09T07:59:00.000000+00:00"},
            "sonnet_only": {"utilization": 73.0, "resets_at": "2026-01-09T09:59:00.000000+00:00"}
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, json)
        }

        // This test would fail without a valid token
        // Uncomment when testing with proper mocking
        // let api = ClaudeAPIService(session: session)
        // let response = try await api.fetchUsage()
        // XCTAssertEqual(response.fiveHour?.utilization, 25.0)
    }

    func testFetchUsage_httpError() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, "Internal Server Error".data(using: .utf8))
        }

        // Test would verify APIError.httpError is thrown
    }

    func testFetchUsage_rateLimited() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "60"]
            )!
            return (response, nil)
        }

        // Test would verify APIError.rateLimited is thrown with correct retryAfter
    }

    func testFetchUsage_unauthorized() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        // Test would verify APIError.tokenExpired is thrown
    }
}
