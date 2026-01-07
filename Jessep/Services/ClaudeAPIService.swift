import Foundation

enum APIError: LocalizedError {
    case tokenNotFound
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case networkError(Error)
    case tokenExpired
    case rateLimited(retryAfter: TimeInterval?)
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .tokenNotFound:
            return "OAuth token not found"
        case .invalidResponse:
            return "Invalid API response"
        case .httpError(let code, let message):
            return "HTTP \(code): \(message ?? "Unknown error")"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .tokenExpired:
            return "Authentication expired. Please re-login to Claude Code."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Retry in \(Int(seconds)) seconds."
            }
            return "Too many requests. Please wait before retrying."
        case .accessDenied:
            return "Access denied. Check your Claude subscription."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited:
            return true
        case .httpError(let code, _):
            return code >= 500
        default:
            return false
        }
    }
}

actor ClaudeAPIService {
    private let baseURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchUsage() async throws -> UsageResponse {
        let token: String
        do {
            token = try KeychainService.getToken()
        } catch {
            throw APIError.tokenNotFound
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Jessep/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw APIError.tokenExpired
        case 403:
            throw APIError.accessDenied
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { Double($0) }
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let message = String(data: data, encoding: .utf8)
            throw APIError.httpError(httpResponse.statusCode, message)
        }

        // Debug: Log raw API response
        if let jsonString = String(data: data, encoding: .utf8) {
            print("[Jessep] API Response: \(jsonString)")
        }

        do {
            let response = try JSONDecoder().decode(UsageResponse.self, from: data)
            print("[Jessep] Decoded - fiveHour: \(response.fiveHour?.utilization ?? -1), sevenDay: \(response.sevenDay?.utilization ?? -1), sonnetOnly: \(response.sonnetOnly?.utilization ?? -1)")
            return response
        } catch {
            print("[Jessep] Decoding error: \(error)")
            throw APIError.decodingError(error)
        }
    }
}
