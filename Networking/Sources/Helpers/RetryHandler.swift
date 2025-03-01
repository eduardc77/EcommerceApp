import Foundation
import OSLog

actor RetryHandler {
    private let retryPolicy: RetryPolicy
    private let rateLimiter: RateLimiter
    
    init(retryPolicy: RetryPolicy, rateLimiter: RateLimiter) {
        self.retryPolicy = retryPolicy
        self.rateLimiter = rateLimiter
    }
    
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        retryPolicy.shouldRetry(error: error, attempt: attempt)
    }
    
    func handleRetry(attempt: Int) async throws {
        let delay = retryPolicy.retryDelay(for: attempt)
        try await rateLimiter.waitForPermit()
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
} 