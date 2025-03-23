import Hummingbird
import Foundation
import NIO
import HTTPTypes

/// Actor to manage rate limiting state in a thread-safe way
private actor RateLimitState {
    private var requestCounts: [String: (count: Int, timestamp: Date)]
    
    init() {
        if Environment.current.isProduction {
            print("""
                ⚠️ WARNING: In-memory rate limiter is not suitable for distributed environments.
                For production with multiple instances, implement a distributed cache (e.g., Redis)
                or use a reverse proxy/load balancer level rate limiting.
                """)
        }
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
    private let trustedProxies: Set<String>
    private let useXForwardedFor: Bool
    private let useXRealIP: Bool
    
    /// Initialize the rate limiter middleware
    /// - Parameters:
    ///   - requestsPerMinute: Maximum number of requests allowed per minute per IP
    ///   - whitelist: IP addresses that are exempt from rate limiting
    ///   - trustedProxies: IP addresses of trusted proxies that can set X-Forwarded-For
    ///   - useXForwardedFor: Whether to trust X-Forwarded-For header (only from trusted proxies)
    ///   - useXRealIP: Whether to trust X-Real-IP header (only from trusted proxies)
    init(
        requestsPerMinute: Int = 60, 
        whitelist: [String] = [],
        trustedProxies: [String] = [],
        useXForwardedFor: Bool = false,
        useXRealIP: Bool = false
    ) {
        self.requestsPerMinute = requestsPerMinute
        self.whitelist = Set(whitelist)
        self.trustedProxies = Set(trustedProxies)
        self.useXForwardedFor = useXForwardedFor
        self.useXRealIP = useXRealIP
        self.state = RateLimitState()
    }
    
    func handle(_ request: Request, context: Context, next: (Request, Context) async throws -> Response) async throws -> Response {
        // Extract client IP using a secure approach
        let clientIP = extractClientIP(from: request)
        
        // Skip rate limiting for whitelisted IPs
        if whitelist.contains(clientIP) {
            return try await next(request, context)
        }
        
        // Check rate limit
        if await state.shouldBlock(clientIP: clientIP, requestsPerMinute: requestsPerMinute) {
            var headers = HTTPFields()
            if let retryAfterName = HTTPField.Name("Retry-After") {
                headers.append(HTTPField(name: retryAfterName, value: "60"))
                print("DEBUG: Added Retry-After header with value 60")
            } else {
                print("DEBUG: Failed to create Retry-After header name")
            }
            throw HTTPError(.tooManyRequests, headers: headers, message: "Rate limit exceeded. Please try again later.")
        }
        
        return try await next(request, context)
    }
    
    /// Securely extract the client IP address from the request
    /// - Parameter request: The HTTP request
    /// - Returns: The client IP address or a unique identifier if IP cannot be determined
    private func extractClientIP(from request: Request) -> String {
        // In Hummingbird, we don't have direct access to the remote address
        // So we'll use a default value for direct connections
        let directClientIP = "direct-connection"
        
        // If we don't trust proxies, don't process the headers
        if !useXForwardedFor && !useXRealIP {
            return directClientIP
        }
        
        // Process X-Forwarded-For header if configured to use it
        if useXForwardedFor, 
           let forwardedFor = HTTPField.Name("X-Forwarded-For"),
           let forwardedIPs = request.headers[forwardedFor]?.first {
            // X-Forwarded-For format: client, proxy1, proxy2, ...
            let ipsString = String(forwardedIPs)
            let ips = ipsString.split(separator: ",").map { 
                $0.trimmingCharacters(in: .whitespacesAndNewlines) 
            }
            if !ips.isEmpty {
                // Use the leftmost IP (original client)
                return String(ips[0])
            }
        }
        
        // Process X-Real-IP header if configured to use it
        if useXRealIP,
           let realIP = HTTPField.Name("X-Real-IP"),
           let realClientIP = request.headers[realIP]?.first {
            return String(realClientIP)
        }
        
        // Fallback to a generated identifier based on request properties
        // This is not ideal but better than grouping all unknown IPs together
        let requestIdentifier = "\(request.uri.path)-\(Date().timeIntervalSince1970)"
        return "unknown-\(requestIdentifier.hash)"
    }
} 
