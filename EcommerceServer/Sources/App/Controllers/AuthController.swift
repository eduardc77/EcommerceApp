import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import HummingbirdFluent
import JWTKit
import CryptoKit
import HTTPTypes
import HummingbirdBcrypt

/// Extension to convert Data to URL-safe base64 string
extension Data {
    /// Converts the data to a URL-safe base64 encoded string by replacing characters that are not URL-safe
    /// - Returns: A URL-safe base64 encoded string
    func base64URLEncodedString() -> String {
        // First encode to regular base64
        let base64String = self.base64EncodedString()

        // Then convert to base64URL by replacing specific characters
        return base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

/// Extension to convert String to a secure token string
extension String {
    /// Converts the string to a URL-safe base64 encoded string
    /// - Returns: A URL-safe base64 encoded string, or empty string if conversion fails
    func toSecureTokenString() -> String {
        // Convert string to data
        guard let data = self.data(using: .utf8) else { return "" }
        return data.base64URLEncodedString()
    }
}

/// Controller handling authentication-related endpoints
struct AuthController {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection
    let kid: JWKIdentifier
    let fluent: Fluent
    let jwtConfig: JWTConfiguration

    // Rate limiting configuration
    private let maxLoginAttempts: Int
    private let loginLockoutDuration: TimeInterval

    // Token store for blacklisting
    private let tokenStore: TokenStoreProtocol

    init(jwtKeyCollection: JWTKeyCollection, kid: JWKIdentifier, fluent: Fluent, tokenStore: TokenStoreProtocol) {
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.fluent = fluent
        self.tokenStore = tokenStore
        
        // Load configuration with graceful fallback
        self.jwtConfig = JWTConfiguration.load()

        // Update rate limiting configuration from loaded config
        self.maxLoginAttempts = jwtConfig.maxFailedAttempts
        self.loginLockoutDuration = jwtConfig.lockoutDuration
    }

    /// Add public routes for auth controller (login, refresh)
    func addPublicRoutes(to group: RouterGroup<Context>) {
        // Add security headers middleware
        group.add(middleware: SecurityHeadersMiddleware())

        group.add(middleware: UserAuthenticator(fluent: fluent))
            .post("login", use: self.login)

        // Refresh token doesn't use JWT middleware since it's validated differently
        group.post("refresh", use: self.refreshToken)
    }

    /// Add protected routes for auth controller (me, logout)
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        // Add security headers middleware
        group.add(middleware: SecurityHeadersMiddleware())

        group.post("logout", use: self.logout)
        group.get("me", use: self.getMe)
        group.post("change-password", use: self.changePassword)
    }

    @available(*, deprecated, message: "Use addPublicRoutes and addProtectedRoutes instead")
    func addRoutes(to group: RouterGroup<Context>) {
        // Add security headers middleware
        group.add(middleware: SecurityHeadersMiddleware())

        // Add user authentication middleware for login
        group.add(middleware: UserAuthenticator(fluent: fluent))
            .post("login", use: self.login)

        // Add JWT authentication middleware for protected routes
        group.add(middleware: JWTAuthenticator(fluent: fluent, tokenStore: tokenStore))
            .post("logout", use: self.logout)
            .get("me", use: self.getMe)

        // Refresh token doesn't use JWT middleware since it's validated differently
        group.post("refresh", use: self.refreshToken)
    }

    /// Login user and return JWT
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: AuthResponse containing tokens and user information
    /// - Throws: HTTPError if authentication fails
    @Sendable func login(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // Check user credentials first
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "Invalid credentials")
        }

        // Check if TOTP is enabled
        if user.twoFactorEnabled {
            // For TOTP-enabled users, we need the code in the X-TOTP-Code header
            guard let totpCodeField = request.headers.first(where: { $0.name.canonicalName == "x-totp-code" }) else {
                return .init(
                    status: .unauthorized,
                    response: AuthResponse(
                        accessToken: "",
                        refreshToken: "",
                        expiresIn: 0,
                        expiresAt: "",
                        user: UserResponse(from: user),
                        requiresTOTP: true
                    )
                )
            }
            
            // Verify TOTP code
            guard try await user.verifyTOTPCode(totpCodeField.value) else {
                throw HTTPError(.unauthorized, message: "Invalid TOTP code")
            }
        }

        let expiresIn = Int(jwtConfig.accessTokenExpiration)
        let accessExpirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date(timeIntervalSinceNow: jwtConfig.refreshTokenExpiration)
        let issuedAt = Date()
        
        // Create access token
        let accessPayload = JWTPayloadData(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: accessExpirationDate),
            type: "access",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )

        // Create refresh token with same version
        let refreshPayload = JWTPayloadData(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: refreshExpirationDate),
            type: "refresh",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )

        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let refreshToken = try await self.jwtKeyCollection.sign(refreshPayload, kid: self.kid)

        // Reset failed login attempts on successful login
        if user.failedLoginAttempts > 0 {
            user.failedLoginAttempts = 0
            user.lastFailedLogin = nil
            try await user.save(on: fluent.db())
        }

        // Log successful login
        context.logger.info("User logged in successfully: \(user.email)")

        let dateFormatter = ISO8601DateFormatter()
        return .init(
            status: .created,
            response: AuthResponse(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresIn: UInt(expiresIn),
                expiresAt: dateFormatter.string(from: accessExpirationDate),
                user: UserResponse(from: user),
                requiresTOTP: false
            )
        )
    }

    /// Refresh JWT token using a refresh token
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: AuthResponse containing new tokens and user information
    /// - Throws: HTTPError if refresh token is invalid or expired
    @Sendable func refreshToken(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // Extract refresh token from request
        struct RefreshRequest: Decodable {
            let refreshToken: String
        }
        let refreshRequest = try await request.decode(as: RefreshRequest.self, context: context)

        // Check if token is blacklisted
        if await tokenStore.isBlacklisted(refreshRequest.refreshToken) {
            throw HTTPError(.unauthorized, message: "Token has been revoked")
        }

        // Verify and decode refresh token
        let refreshPayload = try await self.jwtKeyCollection.verify(refreshRequest.refreshToken, as: JWTPayloadData.self)
        
        // Ensure it's a refresh token
        guard refreshPayload.type == "refresh" else {
            throw HTTPError(.unauthorized, message: "Invalid token type")
        }
        
        // Get user from database - simplified but still thread-safe
        guard let user = try await User.find(UUID(uuidString: refreshPayload.subject.value), on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "User not found")
        }
        
        // Verify token version
        guard let tokenVersion = refreshPayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }

        // Blacklist the used refresh token immediately
        await tokenStore.blacklist(refreshRequest.refreshToken, expiresAt: refreshPayload.expiration.value, reason: .tokenVersionChange)

        // Increment token version to invalidate all previous tokens
        user.tokenVersion += 1
        try await user.save(on: fluent.db())

        // Generate new access token with new version
        let expiresIn = Int(jwtConfig.accessTokenExpiration)
        let accessExpirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date(timeIntervalSinceNow: jwtConfig.refreshTokenExpiration)
        let issuedAt = Date()

        // Create access token
        let accessPayload = JWTPayloadData(
            subject: SubjectClaim(value: refreshPayload.subject.value),
            expiration: ExpirationClaim(value: accessExpirationDate),
            type: "access",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )

        // Create refresh token with same version
        let newRefreshPayload = JWTPayloadData(
            subject: SubjectClaim(value: refreshPayload.subject.value),
            expiration: ExpirationClaim(value: refreshExpirationDate),
            type: "refresh",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )

        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let newRefreshToken = try await self.jwtKeyCollection.sign(newRefreshPayload, kid: self.kid)

        let dateFormatter = ISO8601DateFormatter()
        return EditedResponse(
            status: HTTPResponse.Status.created,
            response: AuthResponse(
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                expiresIn: UInt(expiresIn),
                expiresAt: dateFormatter.string(from: accessExpirationDate),
                user: UserResponse(from: user)
            )
        )
    }

    /// Logout user by invalidating their refresh tokens and blacklisting current access token
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: Empty response with 204 No Content status
    /// - Throws: HTTPError if user is not authenticated
    @Sendable func logout(
        _ request: Request,
        context: Context
    ) async throws -> Response {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "User not authenticated")
        }

        // Increment token version to invalidate all tokens
        let oldVersion = user.tokenVersion
        user.tokenVersion += 1
        try await user.save(on: fluent.db())
        context.logger.info("Incremented token version for user \(user.email): \(oldVersion) -> \(user.tokenVersion)")

        // Add current access token to blacklist if present
        if let token = request.headers.bearer {
            let payload = try await self.jwtKeyCollection.verify(token.token, as: JWTPayloadData.self)
            await tokenStore.blacklist(token.token, expiresAt: payload.expiration.value, reason: .logout)
            context.logger.info("Blacklisted access token for user \(user.email), expires: \(payload.expiration.value)")
        }

        context.logger.info("User logged out: \(user.email)")
        return Response(status: .noContent)
    }

    /// Get authenticated user information
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: UserResponse containing user information
    /// - Throws: HTTPError if user is not authenticated
    @Sendable func getMe(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        return .init(status: .ok, response: UserResponse(from: user))
    }
    
    /// Change user password
    /// Requires authentication and current password verification
    @Sendable func changePassword(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        do {
            // Ensure user is authenticated
            guard let user = context.identity else {
                context.logger.notice("Unauthorized attempt to change password")
                throw HTTPError(.unauthorized, message: "Authentication required to change password")
            }
            
            context.logger.info("Processing password change request for user: \(user.username) (ID: \(user.id?.uuidString ?? "unknown"))")
            
            // Decode the request
            let changePasswordRequest = try await request.decode(as: ChangePasswordRequest.self, context: context)
            
            // Verify current password
            guard let passwordHash = user.passwordHash else {
                // User has no password hash - this is a serious issue
                context.logger.error("User \(user.email) has no password hash")
                throw HTTPError(.internalServerError, message: "Account configuration error. Please contact support.")
            }
            
            // Perform password verification
            let passwordValid = try await NIOThreadPool.singleton.runIfActive({
                Bcrypt.verify(changePasswordRequest.currentPassword, hash: passwordHash)
            })
            
            if !passwordValid {
                context.logger.notice("Invalid current password provided for password change by user \(user.username)")
                throw HTTPError(.unauthorized, message: "Current password is incorrect")
            }
            
            // Validate the new password
            let validator = PasswordValidator()
            let validationResult = validator.validate(changePasswordRequest.newPassword, userInfo: [
                "username": user.username,
                "email": user.email,
                "displayName": user.displayName
            ])
            
            guard validationResult.isValid else {
                let errorMessage = validationResult.firstError ?? "Invalid password"
                context.logger.notice("Password validation failed for user \(user.username): \(errorMessage)")
                throw HTTPError(.badRequest, message: errorMessage)
            }
            
            // Check if password was previously used
            if try await user.isPasswordPreviouslyUsed(changePasswordRequest.newPassword) {
                context.logger.notice("Password reuse attempt by user \(user.username)")
                return .init(
                    status: .badRequest,
                    response: MessageResponse(
                        message: "Password has been previously used. Please choose a different password.",
                        success: false
                    )
                )
            }
            
            // Store current token for invalidation
            let currentToken = request.headers.bearer?.token
            
            // Update the password
            do {
                // We'll update the password directly here since we already checked for reuse
                // Hash the new password with increased cost factor for better security
                let newHash = try await NIOThreadPool.singleton.runIfActive {
                    Bcrypt.hash(changePasswordRequest.newPassword, cost: 12)  // Increased from default
                }
                
                // If there's an existing password hash, add it to history
                if let currentHash = user.passwordHash {
                    var history = user.passwordHistory ?? []
                    history.insert(currentHash, at: 0)
                    
                    // Keep only the most recent passwords
                    if history.count > User.maxPasswordHistoryCount {
                        history = Array(history.prefix(User.maxPasswordHistoryCount))
                    }
                    
                    user.passwordHistory = history
                }
                
                // Update the password hash and timestamp
                user.passwordHash = newHash
                user.passwordUpdatedAt = Date()
                
                // Increment token version to invalidate all existing sessions
                user.tokenVersion += 1
                
                try await user.save(on: fluent.db())
                context.logger.info("Password successfully changed for user \(user.username)")
            } catch {
                context.logger.error("Unexpected error updating password for user \(user.username): \(error.localizedDescription)")
                throw HTTPError(.internalServerError, message: "Failed to update password. Please try again later.")
            }
            
            // Invalidate token immediately
            if let token = currentToken {
                do {
                    // Get token expiration from JWT payload
                    let payload = try await self.jwtKeyCollection.verify(token, as: JWTPayloadData.self)
                    
                    // Blacklist the token
                    await tokenStore.blacklist(token, expiresAt: payload.expiration.value, reason: .passwordChanged)
                    context.logger.info("Successfully blacklisted token after password change for user \(user.username)")
                } catch {
                    // Log the error but don't fail the request - the token version change will still invalidate it
                    context.logger.error("Failed to blacklist token after password change: \(error.localizedDescription)")
                }
            }
            
            return .init(
                status: .created,
                response: MessageResponse(
                    message: "Password changed successfully. Please log in with your new password.",
                    success: true
                )
            )
        } catch let error as HTTPError {
            // Format HTTP errors as MessageResponse
            return .init(
                status: error.status,
                response: MessageResponse(
                    message: error.body ?? "An error occurred",
                    success: false
                )
            )
        } catch {
            // Handle unexpected errors
            context.logger.error("Unexpected error during password change: \(error.localizedDescription)")
            return .init(
                status: .internalServerError,
                response: MessageResponse(
                    message: "An unexpected error occurred. Please try again later.",
                    success: false
                )
            )
        }
    }
}

/// Security Headers Middleware
struct SecurityHeadersMiddleware: MiddlewareProtocol {
    func handle(_ request: Request, context: AppRequestContext, next: (Request, AppRequestContext) async throws -> Response) async throws -> Response {
        var response = try await next(request, context)

        // Add security headers
        response.headers.append(HTTPField(name: HTTPField.Name("X-Content-Type-Options")!, value: "nosniff"))
        response.headers.append(HTTPField(name: HTTPField.Name("X-Frame-Options")!, value: "DENY"))  // Stricter option
        response.headers.append(HTTPField(name: HTTPField.Name("X-XSS-Protection")!, value: "1; mode=block"))
        response.headers.append(HTTPField(name: HTTPField.Name("Strict-Transport-Security")!, value: "max-age=63072000; includeSubDomains; preload"))  // 2 years
        
        // Secure CSP configuration
        let csp = [
            "default-src 'self'",
            "img-src 'self' https:",  // Allow HTTPS images
            "script-src 'self'",      // Only allow scripts from same origin
            "style-src 'self'",       // Only allow styles from same origin
            "connect-src 'self'",     // Only allow connections to same origin
            "font-src 'self'",        // Only allow fonts from same origin
            "object-src 'none'",      // Block <object>, <embed>, and <applet>
            "base-uri 'self'",        // Restrict base URI
            "form-action 'self'",     // Restrict form submissions
            "frame-ancestors 'none'",  // Equivalent to X-Frame-Options: DENY
            "upgrade-insecure-requests"
        ].joined(separator: "; ")
        
        response.headers.append(HTTPField(name: HTTPField.Name("Content-Security-Policy")!, value: csp))
        response.headers.append(HTTPField(name: HTTPField.Name("Referrer-Policy")!, value: "strict-origin-when-cross-origin"))
        
        // Permissions Policy with essential restrictions
        let permissionsPolicy = [
            "accelerometer=()",
            "ambient-light-sensor=()",
            "autoplay=()",
            "battery=()",
            "camera=()",
            "display-capture=()",
            "document-domain=()",
            "encrypted-media=()",
            "fullscreen=(self)",
            "geolocation=()",
            "gyroscope=()",
            "magnetometer=()",
            "microphone=()",
            "midi=()",
            "payment=()",
            "picture-in-picture=()",
            "usb=()",
            "xr-spatial-tracking=()"
        ].joined(separator: ", ")
        
        response.headers.append(HTTPField(name: HTTPField.Name("Permissions-Policy")!, value: permissionsPolicy))
        
        // Add Cross-Origin-Resource-Policy header
        response.headers.append(HTTPField(name: HTTPField.Name("Cross-Origin-Resource-Policy")!, value: "same-origin"))
        
        // Add Cross-Origin-Opener-Policy header
        response.headers.append(HTTPField(name: HTTPField.Name("Cross-Origin-Opener-Policy")!, value: "same-origin"))
        
        // Add Cross-Origin-Embedder-Policy header
        response.headers.append(HTTPField(name: HTTPField.Name("Cross-Origin-Embedder-Policy")!, value: "require-corp"))

        return response
    }
}

struct UserAuthenticator<Context: AuthRequestContext>: AuthenticatorMiddleware where Context.Identity == User {
    let fluent: Fluent

    func authenticate(request: Request, context: Context) async throws -> User? {
        // Get basic auth credentials from request
        guard let basic = request.headers.basic else { return nil }

        // Try to find user by email or username
        let user = try await User.query(on: fluent.db())
            .group(.or) { group in
                group.filter(\.$email == basic.username)
                group.filter(\.$username == basic.username)
            }
            .first()

        guard let user = user else {
            throw HTTPError(.unauthorized, message: "Invalid credentials")
        }

        // Check for account lockout
        if user.isLocked() {
            if let lockoutUntil = user.lockoutUntil {
                let retryAfter = Int(ceil(lockoutUntil.timeIntervalSinceNow))
                var headers = HTTPFields()
                headers.append(HTTPField(name: HTTPField.Name("Retry-After")!, value: "\(max(0, retryAfter))"))
                throw HTTPError(.tooManyRequests,
                                headers: headers,
                                message: "Account is temporarily locked. Please try again later."
                )
            }
            throw HTTPError(.tooManyRequests, message: "Account is temporarily locked. Please try again later.")
        }

        // Verify password
        guard let passwordHash = user.passwordHash else {
            // User has no password hash - this is a serious issue
            context.logger.error("User \(user.email) has no password hash")
            throw HTTPError(.unauthorized, message: "Invalid credentials")
        }
        
        // Perform password verification
        let passwordValid = try await NIOThreadPool.singleton.runIfActive({
            Bcrypt.verify(basic.password, hash: passwordHash)
        })
        
        if !passwordValid {
            // Password verification failed - increment failed attempts
            user.incrementFailedLoginAttempts()
            try await user.save(on: fluent.db())

            // If now locked, throw too many requests
            if user.isLocked() {
                if let lockoutUntil = user.lockoutUntil {
                    let retryAfter = Int(ceil(lockoutUntil.timeIntervalSinceNow))
                    var headers = HTTPFields()
                    headers.append(HTTPField(name: HTTPField.Name("Retry-After")!, value: "\(max(0, retryAfter))"))
                    throw HTTPError(.tooManyRequests,
                                    headers: headers,
                                    message: "Account is temporarily locked. Please try again later."
                    )
                }
                throw HTTPError(.tooManyRequests, message: "Account is temporarily locked. Please try again later.")
            }
            throw HTTPError(.unauthorized, message: "Invalid credentials")
        }

        // Password verification succeeded - reset failed attempts if needed
        if user.failedLoginAttempts > 0 {
            user.resetFailedLoginAttempts()
            try await user.save(on: fluent.db())
        }

        // Update last login timestamp
        user.updateLastLogin()
        try await user.save(on: fluent.db())

        return user
    }
}

/// Request structure for changing a password
struct ChangePasswordRequest: Codable, Sendable {
    let currentPassword: String
    let newPassword: String
}

/// Simple message response structure
struct MessageResponse: Codable, Sendable {
    let message: String
    let success: Bool
}

extension MessageResponse: ResponseEncodable {}
