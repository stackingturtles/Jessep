import Foundation

actor RetryHandler {
    func withRetry<T>(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 2,
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxAttempts {
            do {
                return try await operation()
            } catch let error as APIError where error.isRetryable {
                lastError = error

                // Handle rate limiting with specific delay
                if case .rateLimited(let retryAfter) = error, let delay = retryAfter {
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                // Exponential backoff for other retryable errors
                if attempt < maxAttempts - 1 {
                    let delay = initialDelay * pow(2, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                // Non-retryable error, throw immediately
                throw error
            }
        }

        throw lastError ?? APIError.invalidResponse
    }
}
