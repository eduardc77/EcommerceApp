import Foundation
import Hummingbird
import HTTPTypes

/// CSRF Protection Middleware using Double Submit Cookie pattern
/// This middleware protects against Cross-Site Request Forgery attacks by:
/// 1. Setting a secure, HttpOnly cookie with a CSRF token on GET requests
/// 2. Requiring that same token to be submitted in a custom header for state-changing methods (POST, PUT, DELETE, etc.)
struct CSRFProtectionMiddleware: MiddlewareProtocol {
    private let cookieName: String
    private let headerName: String
    private let secureCookies: Bool
    private let sameSite: SameSite
    private let exemptPaths: [String]
    
    enum SameSite: String {
        case strict = "Strict"
        case lax = "Lax"
        case none = "None"
    }
    
    /// Initialize the CSRF Protection Middleware
    /// - Parameters:
    ///   - cookieName: Name of the cookie that will store the CSRF token
    ///   - headerName: Name of the header that should contain the CSRF token
    ///   - secureCookies: Whether cookies should be marked as Secure (HTTPS only)
    ///   - sameSite: SameSite cookie attribute (Strict, Lax, or None)
    ///   - exemptPaths: Paths that should be exempt from CSRF protection
    init(
        cookieName: String = "XSRF-TOKEN",
        headerName: String = "X-XSRF-TOKEN",
        secureCookies: Bool = true,
        sameSite: String = "lax",
        exemptPaths: [String] = []
    ) {
        self.cookieName = cookieName
        self.headerName = headerName
        self.secureCookies = secureCookies
        
        // Convert string to SameSite enum
        switch sameSite.lowercased() {
        case "strict":
            self.sameSite = .strict
        case "none":
            self.sameSite = .none
        default:
            self.sameSite = .lax
        }
        
        self.exemptPaths = exemptPaths
    }
    
    func handle(_ request: Request, context: AppRequestContext, next: (Request, AppRequestContext) async throws -> Response) async throws -> Response {
        // Skip CSRF protection for exempt paths
        for path in exemptPaths {
            if request.uri.path.hasPrefix(path) {
                return try await next(request, context)
            }
        }
        
        // For safe methods (GET, HEAD, OPTIONS), set the CSRF token cookie
        if request.method == .get || request.method == .head || request.method == .options {
            var response = try await next(request, context)
            
            // Check if the CSRF cookie is already set
            let hasCsrfCookie = request.headers.contains(.cookie) && 
                                (request.headers[values: .cookie].first?.contains(cookieName) ?? false)
            
            if !hasCsrfCookie {
                // Generate a new CSRF token
                let token = generateCSRFToken()
                
                // Set the CSRF token cookie
                let cookieValue = "\(cookieName)=\(token); Path=/; HttpOnly; \(secureCookies ? "Secure; " : "")\(sameSite != .none ? "SameSite=\(sameSite.rawValue)" : "")"
                response.headers.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: cookieValue))
                
                // Also set the token in a non-HttpOnly cookie for JavaScript access
                let jsAccessibleCookie = "\(cookieName)-JS=\(token); Path=/; \(secureCookies ? "Secure; " : "")\(sameSite != .none ? "SameSite=\(sameSite.rawValue)" : "")"
                response.headers.append(HTTPField(name: HTTPField.Name("Set-Cookie")!, value: jsAccessibleCookie))
            }
            
            return response
        }
        
        // For state-changing methods (POST, PUT, DELETE, PATCH), verify the CSRF token
        if request.method == .post || request.method == .put || request.method == .delete || request.method == .patch {
            // Extract the CSRF token from the cookie
            guard let cookieHeader = request.headers[values: .cookie].first,
                  let tokenCookie = parseCookies(String(cookieHeader))[cookieName] else {
                context.logger.warning("CSRF protection failed: No CSRF cookie found")
                throw HTTPError(.forbidden, message: "CSRF token missing")
            }
            
            // Extract the CSRF token from the header
            let csrfHeaderName = HTTPField.Name(headerName)!
            guard let headerToken = request.headers[values: csrfHeaderName].first else {
                context.logger.warning("CSRF protection failed: No CSRF header found")
                throw HTTPError(.forbidden, message: "CSRF token missing from header")
            }
            
            // Verify that the tokens match
            if tokenCookie != String(headerToken) {
                context.logger.warning("CSRF protection failed: Token mismatch")
                throw HTTPError(.forbidden, message: "CSRF token validation failed")
            }
        }
        
        return try await next(request, context)
    }
    
    /// Generate a secure random CSRF token
    private func generateCSRFToken() -> String {
        let randomData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return randomData.base64URLEncodedString()
    }
    
    /// Parse cookies from the Cookie header
    private func parseCookies(_ cookieString: String) -> [String: String] {
        var cookies: [String: String] = [:]
        
        let cookiePairs = cookieString.components(separatedBy: "; ")
        for pair in cookiePairs {
            let keyValue = pair.components(separatedBy: "=")
            if keyValue.count == 2 {
                cookies[keyValue[0]] = keyValue[1]
            }
        }
        
        return cookies
    }
}
