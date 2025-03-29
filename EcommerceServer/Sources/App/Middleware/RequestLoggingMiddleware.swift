import Foundation
import Logging
import HTTPTypes
import Hummingbird

/// Middleware to add request correlation IDs and user context to logs
struct RequestLoggingMiddleware: MiddlewareProtocol {

    init() {}

    func handle(_ request: Request, context: AppRequestContext, next: (Request, AppRequestContext) async throws -> Response) async throws -> Response {
        // Generate and set a request ID for the entire request lifecycle
        let requestId = Logger.generateRequestId()

        // Try to extract user ID if authenticated
        if let user = context.identity {
            if let idString = user.id?.uuidString {
                Logger.setUserId(idString)
            }
        }

        // Log the incoming request with method and path
        Logger.log(
            level: .debug,
            message: "Request: \(request.method.rawValue) \(request.uri.path)",
            metadata: [
                "ip": extractClientIP(from: request),
                "user_agent": request.headers[.userAgent]?.first.flatMap { String(describing: $0) } ?? "unknown"
            ]
        )

        // Process the request
        var response = try await next(request, context)

        // Add the request ID to the response headers
        if let headerName = HTTPField.Name("X-Request-ID") {
            response.headers.append(HTTPField(name: headerName, value: requestId))
        }

        // Log the response
        Logger.log(
            level: .debug,
            message: "Response: \(response.status.code) for \(request.method.rawValue) \(request.uri.path)"
        )

        // Cleanup logging context
        Logger.clearContext()

        return response
    }

    /// Extract client IP from request
    private func extractClientIP(from request: Request) -> String {
        if let xForwardedFor = HTTPField.Name("X-Forwarded-For"),
           let forwardedIPs = request.headers[xForwardedFor]?.first {
            // Convert HTTPField.Value to String safely
            let ipsString = String(describing: forwardedIPs)
            let ips = ipsString.split(separator: ",").map { 
                $0.trimmingCharacters(in: .whitespacesAndNewlines) 
            }
            if !ips.isEmpty {
                return String(ips[0])
            }
        }
        
        if let xRealIP = HTTPField.Name("X-Real-IP"),
           let realClientIP = request.headers[xRealIP]?.first {
            // Convert HTTPField.Value to String safely
            return String(describing: realClientIP)
        }
        
        return "unknown"
    }
}
