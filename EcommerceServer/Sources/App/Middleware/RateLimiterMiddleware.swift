import Hummingbird
import Foundation
import NIO
import HTTPTypes

/// Actor to manage rate limiting state in a thread-safe way
private actor RateLimitState {
    private var requestCounts: [String: (count: Int, timestamp: Date)]
    
    init() {
        self.requestCounts = [:]
    }
    
    func shouldBlock(clientIP: String, requestsPerMinute: Int) -> Bool {
        let now = Date()
        if let lastRequest = requestCounts[clientIP] {
            // Reset count if minute has passed
            if now.timeIntervalSince(lastRequest.timestamp) >= 60 {
                requestCounts[clientIP] = (1, now)
                return false
            } else if lastRequest.count >= requestsPerMinute {
                return true
            } else {
                requestCounts[clientIP] = (lastRequest.count + 1, lastRequest.timestamp)
                return false
            }
        } else {
            requestCounts[clientIP] = (1, now)
            return false
        }
    }
}

/// A simple in-memory rate limiter middleware
final class RateLimiterMiddleware<Context: RequestContext>: MiddlewareProtocol {
    private let requestsPerMinute: Int
    private let whitelist: Set<String>
    private let state: RateLimitState
    
    init(requestsPerMinute: Int = 60, whitelist: [String] = []) {
        self.requestsPerMinute = requestsPerMinute
        self.whitelist = Set(whitelist)
        self.state = RateLimitState()
    }
    
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        // Get client IP from request headers
        let clientIP: String
        if let forwardedFor = HTTPField.Name("X-Forwarded-For"),
           let forwardedIP = request.headers[forwardedFor]?.first {
            clientIP = String(forwardedIP)
        } else if let realIP = HTTPField.Name("X-Real-IP"),
                  let realClientIP = request.headers[realIP]?.first {
            clientIP = String(realClientIP)
        } else {
            clientIP = "unknown"
        }
        
        // Skip rate limiting for whitelisted IPs
        if whitelist.contains(clientIP) {
            return try await next(request, context)
        }
        
        // Check rate limit
        if await state.shouldBlock(clientIP: clientIP, requestsPerMinute: requestsPerMinute) {
            throw HTTPError(.tooManyRequests)
        }
        
        return try await next(request, context)
    }
} 
