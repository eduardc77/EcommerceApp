import Foundation
import Hummingbird
import HummingbirdBasicAuth
import HummingbirdFluent
import HummingbirdBcrypt
import FluentKit
import JWTKit
import HTTPTypes

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
    let emailService: EmailService
    let totpController: TOTPController
    let emailVerificationController: EmailMFAController
    
    // Rate limiting configuration
    private let maxSignInAttempts: Int
    private let signInLockoutDuration: TimeInterval
    
    // Token store for blacklisting
    private let tokenStore: TokenStoreProtocol
    
    init(jwtKeyCollection: JWTKeyCollection, kid: JWKIdentifier, fluent: Fluent, tokenStore: TokenStoreProtocol, emailService: EmailService, totpController: TOTPController, emailVerificationController: EmailMFAController) {
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.fluent = fluent
        self.tokenStore = tokenStore
        self.emailService = emailService
        self.totpController = totpController
        self.emailVerificationController = emailVerificationController
        
        // Load configuration with graceful fallback
        self.jwtConfig = JWTConfiguration.load()
        
        // Update rate limiting configuration from loaded config
        self.maxSignInAttempts = jwtConfig.maxFailedAttempts
        self.signInLockoutDuration = jwtConfig.lockoutDuration
    }
    
    /// Add public routes for auth controller
    func addPublicRoutes(to group: RouterGroup<Context>) {
        // Add security headers middleware
        group.add(middleware: SecurityHeadersMiddleware())
        
        // Core auth
        group.post("sign-up", use: signUp)
            .post("sign-in", use: signIn)
            .post("token/refresh", use: refreshToken)
            .post("cancel", use: cancelAuthentication)
        
        // Initial email verification
        let verifyEmail = group.group("verify-email")
        verifyEmail.post("send", use: sendInitialVerificationEmail)
            .post("confirm", use: verifyInitialEmail)
            .post("resend", use: resendVerificationEmail)
            .get("status", use: getEmailVerificationStatus)
        
        // MFA
        let mfa = group.group("mfa")
        mfa.get("methods", use: getMFAMethods)
            .post("select", use: selectMFAMethod)
        
        // Email MFA
        let emailMFA = mfa.group("email")
        emailMFA.post("send", use: sendEmailMFASignIn)
            .post("verify", use: verifyEmailMFASignIn)
            .post("resend", use: resendEmailMFASignIn)
        
        // TOTP MFA
        let totpMFA = mfa.group("totp")
        totpMFA.post("verify", use: verifyTOTPSignIn)
        
        // Password management
        let password = group.group("password")
        password.post("forgot", use: forgotPassword)
            .post("reset", use: resetPassword)
    }
    
    /// Add protected routes for auth controller
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.get("me", use: getCurrentUser)
            .get("userinfo", use: getUserInfo)  // OpenID Connect standard userinfo endpoint
            .post("password/change", use: changePassword)
            .post("token/revoke", use: revokeAccessToken)
            .post("sign-out", use: signOut)
            .get("sessions", use: listSessions)
            .delete("sessions/:sessionId", use: revokeSession)
            .post("sessions/revoke-all", use: revokeAllOtherSessions)
    }
    
    /// Sign in user with credentials
    /// 
    /// The authentication flow is as follows:
    /// 1. User submits username/email and password
    /// 2. If the user has MFA enabled:
    ///   a. If only one MFA method is enabled, the system automatically selects that method
    ///   b. If multiple MFA methods are enabled, system returns a response with status "MFA_REQUIRED" 
    ///      and a list of available MFA methods
    ///   c. Client calls `/api/v1/auth/mfa/select` with the chosen MFA method (only needed for multiple methods)
    ///   d. System returns a response with status specific to the selected method (e.g., "MFA_TOTP_REQUIRED")
    ///   e. Client completes the specific MFA verification flow for the selected method
    /// 3. If authentication is successful, system returns access and refresh tokens
    ///
    /// This follows industry standard practices where users only need to complete one MFA method
    /// and the selection step is skipped if only one method is available.
    @Sendable func signIn(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // Check user credentials first
        guard let basic = request.headers.basic else {
            throw HTTPError(.unauthorized, message: "Invalid credentials")
        }
        
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
            context.logger.error("User \(user.email) has no password hash")
            throw HTTPError(.unauthorized, message: "Invalid credentials")
        }
        
        // Perform password verification
        let passwordValid = try await NIOThreadPool.singleton.runIfActive({
            Bcrypt.verify(basic.password, hash: passwordHash)
        })
        
        if !passwordValid {
            // Password verification failed - increment failed attempts
            user.incrementFailedSignInAttempts()
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
        if user.failedSignInAttempts > 0 {
            user.resetFailedSignInAttempts()
            try await user.save(on: fluent.db())
        }
        
        // Update last sign in timestamp
        user.updateLastSignIn()
        try await user.save(on: fluent.db())
        
        // Check if any MFA methods are enabled
        let hasTOTP = user.totpMFAEnabled
        let hasEmailMFA = user.emailMFAEnabled
        
        // If user has any MFA method enabled
        if hasTOTP || hasEmailMFA {
            var availableMethods: [MFAMethod] = []
            if hasTOTP { availableMethods.append(.totp) }
            if hasEmailMFA { availableMethods.append(.email) }
            
            // Generate state token
            let stateToken = try await generateStateToken(for: user)
            
            // If only one MFA method is enabled, automatically use that method
            if availableMethods.count == 1 {
                if hasTOTP {
                    return .init(
                        status: .ok,
                        response: AuthResponse(
                            stateToken: stateToken,
                            status: AuthResponse.STATUS_MFA_TOTP_REQUIRED,
                            maskedEmail: user.email.maskEmail()
                        )
                    )
                } else if hasEmailMFA {
                    return .init(
                        status: .ok,
                        response: AuthResponse(
                            tokenType: "Bearer",
                            stateToken: stateToken,
                            status: AuthResponse.STATUS_MFA_EMAIL_REQUIRED,
                            maskedEmail: user.email.maskEmail()
                        )
                    )
                }
            }
            
            // If multiple MFA methods are enabled, let the user choose
            return .init(
                status: .ok,
                response: AuthResponse(
                    stateToken: stateToken,
                    status: AuthResponse.STATUS_MFA_REQUIRED,
                    maskedEmail: user.email.maskEmail(),
                    availableMfaMethods: availableMethods
                )
            )
        }
        
        // For users without MFA, proceed with normal sign in
        var accessTokenExpiration = jwtConfig.accessTokenExpiration
        
        // Check for custom expiration time in header
        if let tokenExpiryHeader = HTTPField.Name("X-Token-Expiry"),
           let customExpiryStr = request.headers[tokenExpiryHeader],
           let customExpiry = TimeInterval(customExpiryStr) {
            // Ensure custom expiry is within reasonable bounds (5 seconds to max configured time)
            accessTokenExpiration = min(max(customExpiry, 5), jwtConfig.accessTokenExpiration)
        }
        
        let expiresIn = Int(accessTokenExpiration)
        let accessExpirationDate = Date(timeIntervalSinceNow: accessTokenExpiration)
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
        
        // Creates necessary records after successful authentication
        // - Parameters:
        //   - user: The authenticated user
        //   - request: The HTTP request
        //   - accessToken: The JWT access token
        //   - refreshToken: The JWT refresh token
        //   - accessPayload: The access token payload
        //   - refreshPayload: The refresh token payload
        //   - accessExpirationDate: Expiration date for the access token
        //   - refreshExpirationDate: Expiration date for the refresh token
        //   - context: Request context
        await createTokenOnSuccessfulAuthentication(
            user: user,
            request: request,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessPayload: accessPayload,
            refreshPayload: refreshPayload,
            accessExpirationDate: accessExpirationDate,
            refreshExpirationDate: refreshExpirationDate,
            context: context
        )
        
        let dateFormatter = ISO8601DateFormatter()
        
        // Create response
        let response = AuthResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: "Bearer",
            expiresIn: UInt(expiresIn),
            expiresAt: dateFormatter.string(from: accessExpirationDate),
            user: UserResponse(from: user),
            status: AuthResponse.STATUS_SUCCESS
        )
        
        return .init(
            status: .ok,
            response: response
        )
    }
    
    /// Creates necessary records after successful authentication
    /// - Parameters:
    ///   - user: The authenticated user
    ///   - request: The HTTP request
    ///   - accessToken: The JWT access token
    ///   - refreshToken: The JWT refresh token
    ///   - accessPayload: The access token payload
    ///   - refreshPayload: The refresh token payload
    ///   - accessExpirationDate: Expiration date for the access token
    ///   - refreshExpirationDate: Expiration date for the refresh token
    ///   - context: Request context
    private func createTokenOnSuccessfulAuthentication(
        user: User,
        request: Request,
        accessToken: String,
        refreshToken: String,
        accessPayload: JWTPayloadData,
        refreshPayload: JWTPayloadData,
        accessExpirationDate: Date,
        refreshExpirationDate: Date,
        context: Context
    ) async {
        // Create session record (but don't fail if it doesn't work)
        var sessionCreated = false
        var sessionId: UUID? = nil
        do {
            let session = try await createSessionRecord(
                userID: user.requireID(),
                request: request,
                tokenID: accessPayload.id,
                context: context
            )
            sessionId = session.id
            sessionCreated = true
            context.logger.info("Session created successfully")
            
            // Create token record if session was created successfully
            if let sessionId = sessionId {
                _ = try await createTokenRecord(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    accessJti: accessPayload.id,
                    refreshJti: refreshPayload.id,
                    accessExpirationDate: accessExpirationDate,
                    refreshExpirationDate: refreshExpirationDate,
                    sessionId: sessionId
                )
                context.logger.info("Token record created successfully")
            }
        } catch {
            context.logger.error("Failed to create session record: \(error)")
            // Keep track of failures for monitoring
            if let fluentError = error as? FluentError {
                context.logger.error("Database error during session creation: \(fluentError)")
            }
            // Continue with authentication even if session creation fails
        }
        
        // Update metrics for session creation tracking
        if !sessionCreated {
            context.logger.warning("Authentication succeeded but session creation failed for user: \(user.email)")
        }
    }
    
    /// Creates a session record for a successful authentication
    /// - Parameters:
    ///   - userID: User ID
    ///   - request: The HTTP request that contains device info
    ///   - tokenID: JWT token ID
    ///   - context: Request context for logging
    /// - Returns: The created session
    private func createSessionRecord(
        userID: UUID,
        request: Request,
        tokenID: String,
        context: Context
    ) async throws -> Session {
        let db = fluent.db()
        
        context.logger.debug("Creating session for user ID: \(userID.uuidString), tokenID: \(tokenID)")
        
        // Extract session information
        let deviceName: String
        let userAgent: String
        
        if let deviceNameHeader = HTTPField.Name("X-Device-Name") {
            deviceName = request.headers[deviceNameHeader] ?? "Unknown Device"
        } else {
            deviceName = "Unknown Device"
        }
        
        if let userAgentHeader = HTTPField.Name("User-Agent") {
            userAgent = request.headers[userAgentHeader] ?? "Unknown"
        } else {
            userAgent = "Unknown"
        }
        
        // Get IP address with fallback
        let ipAddress: String = {
            if let forwardedForName = HTTPField.Name("X-Forwarded-For"),
               let forwardedFor = request.headers[forwardedForName]?.split(separator: ",").first {
                return String(forwardedFor).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if let realIPName = HTTPField.Name("X-Real-IP"),
                      let realIP = request.headers[realIPName] {
                return String(realIP)
            }
            return "127.0.0.1"
        }()
        
        context.logger.debug("Session details - Device: \(deviceName), UA: \(userAgent), IP: \(ipAddress)")
        
        // First check if we have an existing session with this token ID
        // This prevents duplicate session records and is more robust
        if let existingSession = try await Session.query(on: db)
            .filter(\.$tokenId == tokenID)
            .first() {
            context.logger.debug("Found existing session with this token ID: \(existingSession.id?.uuidString ?? "unknown")")
            
            // Update the existing session instead of creating a new one
            existingSession.lastUsedAt = Date()
            existingSession.isActive = true
            try await existingSession.save(on: db)
            context.logger.debug("Updated existing session")
            return existingSession
        }
        
        // Create new session in a transaction
        return try await db.transaction { database in
            // Verify user exists
            guard try await User.find(userID, on: database) != nil else {
                context.logger.error("Failed to create session: User with ID \(userID.uuidString) not found")
                throw HTTPError(.internalServerError, message: "User not found")
            }
            
            // Check for existing sessions and manage the total count
            let sessionCount = try await Session.query(on: database)
                .filter(\.$user.$id == userID)
                .filter(\.$isActive == true)
                .count()
            
            context.logger.debug("User has \(sessionCount) active sessions")
            
            // If over the limit, deactivate oldest sessions
            let maxActiveSessions = self.jwtConfig.maxRefreshTokens
            if sessionCount >= maxActiveSessions {
                context.logger.debug("User has reached max sessions (\(maxActiveSessions)), will deactivate oldest")
                
                // Get oldest sessions
                let oldestSessions = try await Session.query(on: database)
                    .filter(\.$user.$id == userID)
                    .filter(\.$isActive == true)
                    .sort(\.$lastUsedAt, .ascending)
                    .limit(sessionCount - maxActiveSessions + 1)
                    .all()
                
                for oldSession in oldestSessions {
                    context.logger.debug("Deactivating old session: \(oldSession.id?.uuidString ?? "unknown")")
                    oldSession.isActive = false
                    try await oldSession.save(on: database)
                }
            }
            
            // Create copies of variables to avoid capture issues in concurrent code
            let sessionDeviceName = deviceName
            let sessionIPAddress = ipAddress
            let sessionUserAgent = userAgent
            
            // Create new session record
            let session = Session()
            session.id = UUID()
            session.$user.id = userID
            session.deviceName = sessionDeviceName
            session.ipAddress = sessionIPAddress
            session.userAgent = sessionUserAgent
            session.tokenId = tokenID
            session.isActive = true
            session.lastUsedAt = Date()
            session.createdAt = Date()
            
            context.logger.debug("Saving new session with ID: \(session.id?.uuidString ?? "unknown")")
            
            try await session.save(on: database)
            
            context.logger.info("Session created successfully for user ID: \(userID.uuidString)")
            return session
        }
    }
    
    /// Sign up a new user (public endpoint)
    /// Returns a stateToken for email verification
    @Sendable func signUp(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        let createUser = try await request.decode(
            as: SignUpRequest.self,
            context: context
        )
        
        let db = self.fluent.db()
        
        // Check if username exists
        if let _ = try await User.query(on: db)
            .filter(\.$username == createUser.username)
            .first() {
            context.logger.notice("Username already exists: \(createUser.username)")
            throw HTTPError(.conflict, message: "Username already exists")
        }
        
        // Check if email exists
        if let _ = try await User.query(on: db)
            .filter(\.$email == createUser.email)
            .first() {
            context.logger.notice("Email already exists: \(createUser.email)")
            throw HTTPError(.conflict, message: "Email already exists")
        }
        
        // Create and save user with default customer role
        let user = try await User(from: createUser)
        user.role = .customer  // Always set to customer for public registration
        try await user.save(on: db)
        
        // Generate temporary token for email verification
        let tempTokenPayload = JWTPayloadData(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 600)), // 10 minutes
            type: "email_verification",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: Date(),
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        let stateToken = try await self.jwtKeyCollection.sign(tempTokenPayload, kid: self.kid)
        
        // Return AuthResponse with stateToken and user info
        return .init(
            status: .created,
            response: AuthResponse(
                tokenType: "Bearer",
                stateToken: stateToken,
                status: AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED,
                maskedEmail: user.email.maskEmail()
            )
        )
    }
    
    /// Verify TOTP during sign-in
    @Sendable func verifyTOTPSignIn(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        let verifyRequest = try await request.decode(as: TOTPVerificationRequest.self, context: context)
        
        // Verify and decode state token
        let stateTokenPayload = try await self.jwtKeyCollection.verify(verifyRequest.stateToken, as: JWTPayloadData.self)
        
        // Ensure it's a state token
        guard stateTokenPayload.type == "state_token" else {
            throw HTTPError(.unauthorized, message: "Invalid token type")
        }
        
        // Get user from database
        guard let user = try await User.find(UUID(uuidString: stateTokenPayload.subject.value), on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "User not found")
        }
        
        // Verify token version
        guard let tokenVersion = stateTokenPayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }
        
        // Check if account is locked
        if user.isLocked() {
            if let until = user.lockoutUntil {
                throw HTTPError(.unauthorized, message: "Account is locked. Try again after \(until)")
            }
            throw HTTPError(.unauthorized, message: "Account is locked")
        }
        
        // Verify TOTP code
        guard let secret = user.totpMFASecret else {
            throw HTTPError(.badRequest, message: "MFA is not properly configured")
        }
        
        if !TOTPUtils.verifyTOTPCode(code: verifyRequest.code, secret: secret) {
            // Increment failed attempts
            user.incrementFailedSignInAttempts()
            try await user.save(on: fluent.db())
            
            // Check if now locked
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
            
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Reset failed attempts if needed
        if user.failedSignInAttempts > 0 {
            user.resetFailedSignInAttempts()
            try await user.save(on: fluent.db())
        }
        
        // Complete sign in by creating tokens
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
        
        // Create refresh token
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
        
        // Creates necessary records after successful authentication
        // - Parameters:
        //   - user: The authenticated user
        //   - request: The HTTP request
        //   - accessToken: The JWT access token
        //   - refreshToken: The JWT refresh token
        //   - accessPayload: The access token payload
        //   - refreshPayload: The refresh token payload
        //   - accessExpirationDate: Expiration date for the access token
        //   - refreshExpirationDate: Expiration date for the refresh token
        //   - context: Request context
        await createTokenOnSuccessfulAuthentication(
            user: user,
            request: request,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessPayload: accessPayload,
            refreshPayload: refreshPayload,
            accessExpirationDate: accessExpirationDate,
            refreshExpirationDate: refreshExpirationDate,
            context: context
        )
        
        let dateFormatter = ISO8601DateFormatter()
        return .init(
            status: .ok,
            response: AuthResponse(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: "Bearer",
                expiresIn: UInt(expiresIn),
                expiresAt: dateFormatter.string(from: accessExpirationDate),
                user: UserResponse(from: user),
                status: AuthResponse.STATUS_SUCCESS
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
            
            enum CodingKeys: String, CodingKey {
                case refreshToken = "refresh_token"
            }
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
        
        // Create token rotation service
        let tokenRotationService = TokenRotationService(
            db: fluent.db(),
            tokenStore: tokenStore,
            logger: context.logger
        )
        
        // Check if token is valid for rotation
        let isValidForRotation = try await tokenRotationService.isValidForRotation(jti: refreshPayload.id)
        if !isValidForRotation {
            // If not valid, immediately blacklist the token
            await tokenStore.blacklist(refreshRequest.refreshToken, expiresAt: refreshPayload.expiration.value, reason: .tokenVersionChange)
            throw HTTPError(.unauthorized, message: "This refresh token cannot be used")
        }
        
        // Blacklist the used refresh token immediately (keep this for backward compatibility)
        await tokenStore.blacklist(refreshRequest.refreshToken, expiresAt: refreshPayload.expiration.value, reason: .tokenVersionChange)
        
        // Generate new tokens
        let expiresIn = Int(jwtConfig.accessTokenExpiration)
        let accessExpirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date(timeIntervalSinceNow: jwtConfig.refreshTokenExpiration)
        let issuedAt = Date()
        
        // Create new token IDs
        let newAccessJti = UUID().uuidString
        let newRefreshJti = UUID().uuidString
        
        // Create access token
        let accessPayload = JWTPayloadData(
            subject: SubjectClaim(value: refreshPayload.subject.value),
            expiration: ExpirationClaim(value: accessExpirationDate),
            type: "access",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: newAccessJti,
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
            id: newRefreshJti,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let newRefreshToken = try await self.jwtKeyCollection.sign(newRefreshPayload, kid: self.kid)
        
        // Track and rotate tokens
        if let existingToken = try await Token.query(on: fluent.db())
            .filter(\.$refreshToken == refreshRequest.refreshToken)
            .first() {
            // Get session ID
            let sessionId = existingToken.$session.id
            
            // Create new token entry
            let token = Token(
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                accessTokenExpiresAt: accessExpirationDate,
                refreshTokenExpiresAt: refreshExpirationDate,
                jti: newRefreshJti,
                parentJti: refreshPayload.id,
                familyId: existingToken.familyId,
                generation: existingToken.generation + 1,
                sessionId: sessionId
            )
            try await token.save(on: fluent.db())
            
            // Apply rotation
            _ = try await tokenRotationService.rotateToken(
                oldJti: refreshPayload.id,
                newJti: newRefreshJti,
                refreshToken: newRefreshToken,
                expiresAt: refreshExpirationDate
            )
        } else {
            // Fallback for existing tokens that weren't properly tracked
            // This handles backward compatibility
            context.logger.warning("Token not found in database, creating new record")
            
            // Look up session by user and timestamp (best effort)
            let session = try await Session.query(on: fluent.db())
                .filter(\.$user.$id == user.requireID())
                .filter(\.$isActive == true)
                .sort(\.$lastUsedAt, .descending)
                .first()
            
            if let session = session {
                // Create new token with default values
                let token = Token(
                    accessToken: accessToken,
                    refreshToken: newRefreshToken,
                    accessTokenExpiresAt: accessExpirationDate,
                    refreshTokenExpiresAt: refreshExpirationDate,
                    jti: newRefreshJti,
                    parentJti: refreshPayload.id,
                    familyId: UUID(), // New family
                    generation: 0,
                    sessionId: session.id!
                )
                try await token.save(on: fluent.db())
            }
        }
        
        let dateFormatter = ISO8601DateFormatter()
        return EditedResponse(
            status: .ok,
            response: AuthResponse(
                accessToken: accessToken,
                refreshToken: newRefreshToken,
                tokenType: "Bearer",
                expiresIn: UInt(expiresIn),
                expiresAt: dateFormatter.string(from: accessExpirationDate),
                user: UserResponse(from: user),
                status: AuthResponse.STATUS_SUCCESS
            )
        )
    }
    
    /// Sign out user by invalidating their refresh tokens and blacklisting current access token
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: Empty response with 204 No Content status
    /// - Throws: HTTPError if user is not authenticated
    @Sendable func signOut(
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
        
        // Mark all sessions as inactive
        try await Session.query(on: fluent.db())
            .filter(\.$user.$id == user.requireID())
            .filter(\.$isActive == true)
            .set(\.$isActive, to: false)
            .update()
        
        // Add current access token to blacklist if present
        if let token = request.headers.bearer {
            let payload = try await self.jwtKeyCollection.verify(token.token, as: JWTPayloadData.self)
            await tokenStore.blacklist(token.token, expiresAt: payload.expiration.value, reason: .signOut)
            context.logger.info("Blacklisted access token for user \(user.email), expires: \(payload.expiration.value)")
        }
        
        context.logger.info("User logged out: \(user.email)")
        return Response(status: .noContent)
    }
    
    /// List all active sessions for the authenticated user
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: List of user sessions
    @Sendable func listSessions(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<SessionListResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "User not authenticated")
        }
        
        let logger = context.logger
        let userId = user.id?.uuidString ?? "unknown"
        logger.debug("Fetching sessions for user ID: \(userId)")
        
        // Get the current token ID from Authorization header
        var currentTokenId: String? = nil
        if let bearerToken = request.headers.bearer?.token {
            do {
                let payload = try await self.jwtKeyCollection.verify(bearerToken, as: JWTPayloadData.self)
                currentTokenId = payload.id
                logger.debug("Current token ID: \(payload.id)")
            } catch {
                logger.warning("Failed to verify bearer token: \(error)")
                // Continue without current token ID
            }
        } else {
            logger.debug("No bearer token in request")
        }
        
        // Get all active sessions for user
        do {
            let db = fluent.db()
            
            // Diagnostic check: Make sure user exists in database first
            let userCheck = try await User.find(user.id, on: db)
            if userCheck == nil {
                logger.error("User exists in context but not in database: \(userId)")
                throw HTTPError(.internalServerError, message: "User data inconsistency")
            }
            
            // Check if sessions table exists using direct SQL
            logger.debug("Verifying sessions table access")
            
            // Get all active sessions for user with error handling
            let sessions = try await Session.query(on: db)
                .filter(\.$user.$id == user.requireID())
                .filter(\.$isActive == true)
                .sort(\.$lastUsedAt, .descending)
                .all()
            
            logger.debug("Found \(sessions.count) active sessions")
            
            // If no session found for current token, create one now
            if let tokenId = currentTokenId, 
                !sessions.contains(where: { $0.tokenId == tokenId }) {
                logger.warning("No session found for current token, creating one now")
                
                // Try to create a session for the current token
                do {
                    let session = try await createSessionRecord(
                        userID: user.requireID(),
                        request: request,
                        tokenID: tokenId,
                        context: context
                    )
                    logger.info("Created missing session: \(session.id?.uuidString ?? "unknown")")
                    
                    // Re-fetch the sessions to include the new one
                    let updatedSessions = try await Session.query(on: db)
                        .filter(\.$user.$id == user.requireID())
                        .filter(\.$isActive == true)
                        .sort(\.$lastUsedAt, .descending)
                        .all()
                    
                    // Map to response objects
                    let sessionResponses = updatedSessions.map { 
                        SessionResponse(from: $0, currentTokenId: currentTokenId) 
                    }
                    
                    return .init(
                        status: .ok,
                        response: SessionListResponse(
                            sessions: sessionResponses, 
                            currentSessionId: sessionResponses.first(where: { $0.isCurrent })?.id
                        )
                    )
                } catch {
                    logger.error("Failed to create missing session: \(error)")
                    // Continue with existing sessions
                }
            }
            
            // Map to response objects
            let sessionResponses = sessions.map { 
                SessionResponse(from: $0, currentTokenId: currentTokenId) 
            }
            
            return .init(
                status: .ok,
                response: SessionListResponse(
                    sessions: sessionResponses, 
                    currentSessionId: sessionResponses.first(where: { $0.isCurrent })?.id
                )
            )
        } catch {
            logger.error("Failed to retrieve sessions: \(error)")
            throw HTTPError(.internalServerError, message: "Failed to retrieve sessions")
        }
    }
    
    /// Revoke a specific session
    /// - Parameters:
    ///   - request: The incoming HTTP request with session ID
    ///   - context: The application request context
    /// - Returns: Success message
    @Sendable func revokeSession(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "User not authenticated")
        }
        
        // Extract session ID from path parameters
        guard let sessionIdParam = request.uri.path.split(separator: "/").last.map(String.init),
              let sessionId = UUID(uuidString: sessionIdParam) else {
            throw HTTPError(.badRequest, message: "Invalid session ID")
        }
        
        // Find the session
        guard let session = try await Session.query(on: fluent.db())
            .filter(\.$id == sessionId)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw HTTPError(.notFound, message: "Session not found")
        }
        
        // Check if this is the current session
        var isCurrentSession = false
        if let bearerToken = request.headers.bearer?.token {
            do {
                let payload = try await self.jwtKeyCollection.verify(bearerToken, as: JWTPayloadData.self)
                isCurrentSession = payload.id == session.tokenId
            } catch {
                isCurrentSession = false
            }
        }
        
        // Mark session as inactive
        session.isActive = false
        try await session.save(on: fluent.db())
        
        // If this is the current session, blacklist the current token and increment token version
        if isCurrentSession {
            if let bearerToken = request.headers.bearer?.token {
                let payload = try await self.jwtKeyCollection.verify(bearerToken, as: JWTPayloadData.self)
                await tokenStore.blacklist(bearerToken, expiresAt: payload.expiration.value, reason: .sessionRevoked)
                
                // Increment token version to invalidate all tokens for this session
                user.tokenVersion += 1
                try await user.save(on: fluent.db())
            }
        } else {
            // For non-current sessions, just blacklist the specific token
            await tokenStore.blacklist(session.tokenId, expiresAt: Date().addingTimeInterval(3600), reason: .sessionRevoked)
        }
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Session revoked successfully",
                success: true
            )
        )
    }
    
    /// Revoke all sessions except the current one
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: Success message
    @Sendable func revokeAllOtherSessions(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "User not authenticated")
        }
        
        // Get current session token ID
        var currentTokenId: String? = nil
        if let bearerToken = request.headers.bearer?.token {
            do {
                let payload = try await self.jwtKeyCollection.verify(bearerToken, as: JWTPayloadData.self)
                currentTokenId = payload.id
                context.logger.debug("Current token ID: \(payload.id)")
            } catch {
                context.logger.warning("Failed to verify bearer token: \(error)")
                throw HTTPError(.unauthorized, message: "Invalid authentication token")
            }
        } else {
            context.logger.debug("No bearer token in request")
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        guard let tokenId = currentTokenId else {
            throw HTTPError(.internalServerError, message: "Failed to identify current session")
        }
        
        // Find current session to keep active
        guard let currentSession = try await Session.query(on: fluent.db())
            .filter(\.$tokenId == tokenId)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw HTTPError(.notFound, message: "Current session not found")
        }
        
        // Get all other active sessions
        let otherSessions = try await Session.query(on: fluent.db())
            .filter(\.$user.$id == user.requireID())
            .filter(\.$id != currentSession.id!)
            .filter(\.$isActive == true)
            .all()
        
        // Blacklist all other session tokens
        for session in otherSessions {
            session.isActive = false
            await tokenStore.blacklist(
                session.tokenId,
                expiresAt: Date().addingTimeInterval(86400), // 24 hours
                reason: .sessionRevoked
            )
        }
        
        // Save changes to all sessions
        try await Session.query(on: fluent.db())
            .filter(\.$user.$id == user.requireID())
            .filter(\.$id != currentSession.id!)
            .filter(\.$isActive == true)
            .set(\.$isActive, to: false)
            .update()
        
        // Increment token version to invalidate all other tokens
        user.tokenVersion += 1
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "All other sessions have been revoked",
                success: true
            )
        )
    }
    
    /// Get authenticated user information
    /// - Parameters:
    ///   - request: The incoming HTTP request
    ///   - context: The application request context
    /// - Returns: UserResponse containing user information
    /// - Throws: HTTPError if user is not authenticated
    @Sendable func getCurrentUser(
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
                throw HTTPError(.badRequest, message: "Password has been previously used. Please choose a different password.")
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
            } catch let error as HTTPError {
                // Re-throw HTTPError to be handled by middleware
                throw error
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
                status: .ok,
                response: MessageResponse(
                    message: "Password changed successfully. Please log in with your new password.",
                    success: true
                )
            )
        } catch {
            // Handle all errors consistently
            context.logger.error("Unexpected error during password change: \(error.localizedDescription)")
            throw HTTPError(.internalServerError, message: "An unexpected error occurred. Please try again later.")
        }
    }
    
    /// Request a new email verification code during sign in
    @Sendable func requestEmailCode(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Get state token from request body
        struct EmailMFARequest: Codable {
            let state_token: String
        }
        
        let mfaRequest = try await request.decode(as: EmailMFARequest.self, context: context)
        
        // Verify and decode state token
        let stateTokenPayload = try await self.jwtKeyCollection.verify(mfaRequest.state_token, as: JWTPayloadData.self)
        
        // Ensure it's a valid token type
        guard stateTokenPayload.type == "state_token" || stateTokenPayload.type == "email_verification" else {
            throw HTTPError(.unauthorized, message: "Invalid token type")
        }
        
        // Get user from database
        guard let user = try await User.find(UUID(uuidString: stateTokenPayload.subject.value), on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "User not found")
        }
        
        // Verify token version
        guard let tokenVersion = stateTokenPayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }
        
        // Check if email verification is enabled
        guard user.emailVerified else {
            throw HTTPError(.badRequest, message: "Email verification is not enabled for this account")
        }
        
        // Get user ID first
        let userID = try user.requireID()
        
        // Check for existing verification code and cooldown
        if let existingCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "mfa_sign_in")
            .first() {
            
            if existingCode.isWithinCooldown {
                let remaining = existingCode.remainingCooldown
                var headers = HTTPFields()
                headers.append(HTTPField(name: HTTPField.Name("Retry-After")!, value: "\(remaining)"))
                throw HTTPError(
                    .tooManyRequests,
                    headers: headers,
                    message: "Please wait before requesting another code"
                )
            }
            
            // Delete the expired code
            try await existingCode.delete(on: fluent.db())
        }
        
        // Generate and store verification code
        let code = EmailVerificationCode.generateCode()
        let verificationCode = EmailVerificationCode(
            userID: userID,
            code: code,
            type: "mfa_sign_in",
            expiresAt: Date().addingTimeInterval(300) // 5 minutes
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send verification email
        try await emailService.sendEmailMFASignIn(to: user.email, code: code)
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification code sent to your email",
                success: true
            )
        )
    }
    
    /// Request a password reset for a user
    @Sendable func forgotPassword(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        let forgotRequest = try await request.decode(as: ForgotPasswordRequest.self, context: context)
        
        // Try to find user by email
        guard let user = try await User.query(on: fluent.db())
            .filter(\.$email == forgotRequest.email)
            .first() else {
            // Return success even if user not found to prevent email enumeration
            return .init(
                status: .ok,
                response: MessageResponse(
                    message: "If an account exists with that email, a password reset link has been sent",
                    success: true
                )
            )
        }
        
        // Delete any existing verification codes for this user
        let userID = try user.requireID()
        try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id == userID)
            .filter(\.$type == "password_reset")
            .delete()
        
        // Generate and store verification code
        let code = EmailVerificationCode.generateCode()
        let verificationCode = EmailVerificationCode(
            userID: userID,
            code: code,
            type: "password_reset",
            expiresAt: Date().addingTimeInterval(1800) // 30 minutes
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send password reset email
        try await emailService.sendPasswordResetEmail(to: user.email, code: code)
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "If an account exists with that email, a password reset link has been sent",
                success: true
            )
        )
    }
    
    /// Reset a user's password using a verification code
    @Sendable func resetPassword(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        let resetRequest = try await request.decode(as: ResetPasswordRequest.self, context: context)
        
        // Find user by email
        guard let user = try await User.query(on: fluent.db())
            .filter(\.$email, .equal, resetRequest.email)
            .first() else {
            throw HTTPError(.badRequest, message: "Invalid reset request")
        }
        
        // Find and verify the reset code
        let userID = try user.requireID()
        guard let verificationCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id == userID)
            .filter(\.$type == "password_reset")
            .sort(\.$createdAt, .descending)
            .first() else {
            throw HTTPError(.badRequest, message: "Invalid or expired reset code")
        }
        
        // Check if code is expired
        if verificationCode.isExpired {
            try await verificationCode.delete(on: fluent.db())
            throw HTTPError(.badRequest, message: "Reset code has expired")
        }
        
        // Check attempts
        if verificationCode.hasExceededAttempts {
            try await verificationCode.delete(on: fluent.db())
            throw HTTPError(.tooManyRequests, message: "Too many attempts. Please request a new code.")
        }
        
        // Verify the code
        if verificationCode.code != resetRequest.code {
            verificationCode.incrementAttempts()
            try await verificationCode.save(on: fluent.db())
            throw HTTPError(.badRequest, message: "Invalid reset code")
        }
        
        // Validate the new password
        let validator = PasswordValidator()
        let validationResult = validator.validate(resetRequest.newPassword, userInfo: [
            "username": user.username,
            "email": user.email,
            "displayName": user.displayName
        ])
        
        guard validationResult.isValid else {
            let errorMessage = validationResult.firstError ?? "Invalid password"
            throw HTTPError(.badRequest, message: errorMessage)
        }
        
        // Check if password was previously used
        if try await user.isPasswordPreviouslyUsed(resetRequest.newPassword) {
            throw HTTPError(.badRequest, message: "Password has been previously used. Please choose a different password.")
        }
        
        // Update the password
        do {
            // Hash the new password with increased cost factor
            let newHash = try await NIOThreadPool.singleton.runIfActive {
                Bcrypt.hash(resetRequest.newPassword, cost: 12)
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
            
            // Delete the verification code after successful reset
            try await verificationCode.delete(on: fluent.db())
            
            return .init(
                status: .ok,
                response: MessageResponse(
                    message: "Password has been reset successfully. Please log in with your new password.",
                    success: true
                )
            )
        } catch {
            context.logger.error("Unexpected error updating password for user \(user.username): \(error.localizedDescription)")
            throw HTTPError(.internalServerError, message: "Failed to update password. Please try again later.")
        }
    }
    
    /// Send or resend verification code for initial email verification
    @Sendable func sendInitialVerificationEmail(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Decode request
        struct SendCodeRequest: Codable {
            let email: String
        }
        let sendRequest = try await request.decode(as: SendCodeRequest.self, context: context)
        
        // Find user
        guard let user = try await User.query(on: fluent.db())
            .filter(\.$email, .equal, sendRequest.email)
            .first() else {
            // Return success even if user not found to prevent email enumeration
            return .init(
                status: .ok,
                response: MessageResponse(
                    message: "If an account exists with that email, a verification code has been sent",
                    success: true
                )
            )
        }
        
        // Check if already verified
        if user.emailVerified {
            throw HTTPError(
                .conflict,
                message: "Email is already verified"
            )
        }
        
        // Check for existing code and cooldown
        if let existingCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, try user.requireID())
            .filter(\.$type, .equal, "email_verify")
            .first() {
            
            if existingCode.isWithinCooldown {
                let remaining = existingCode.remainingCooldown
                var headers = HTTPFields()
                headers.append(HTTPField(name: HTTPField.Name("Retry-After")!, value: "\(remaining)"))
                throw HTTPError(
                    .tooManyRequests,
                    headers: headers,
                    message: "Please wait before requesting another code"
                )
            }
            
            // Delete expired code
            try await existingCode.delete(on: fluent.db())
        }
        
        // Generate new code
        let code = EmailVerificationCode.generateCode()
        let verificationCode = EmailVerificationCode(
            userID: try user.requireID(),
            code: code,
            type: "email_verify",
            expiresAt: Date().addingTimeInterval(300) // 5 minutes (changed from 30 minutes for consistency)
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send verification email
        try await emailService.sendVerificationEmail(to: user.email, code: code)
        
        context.logger.info("Sent initial verification email to user: \(user.email)")
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification email sent",
                success: true
            )
        )
    }
    
    /// Verify initial email after registration
    @Sendable func verifyInitialEmail(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // Decode verification request
        struct VerifyRequest: Codable {
            let email: String
            let code: String
        }
        let verifyRequest = try await request.decode(as: VerifyRequest.self, context: context)
        
        // Find user
        guard let user = try await User.query(on: fluent.db())
            .filter(\.$email, .equal, verifyRequest.email)
            .first() else {
            throw HTTPError(.badRequest, message: "Invalid verification request")
        }
        
        // Check if already verified
        if user.emailVerified {
            throw HTTPError(.badRequest, message: "Email already verified")
        }
        
        // Find verification code
        guard let verificationCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, try user.requireID())
            .filter(\.$type, .equal, "email_verify")
            .sort(\.$createdAt, .descending)
            .first() else {
            throw HTTPError(.badRequest, message: "No verification code found")
        }
        
        // Check if code is expired
        if verificationCode.isExpired {
            try await verificationCode.delete(on: fluent.db())
            throw HTTPError(.badRequest, message: "Verification code has expired")
        }
        
        // Check attempts
        if verificationCode.hasExceededAttempts {
            try await verificationCode.delete(on: fluent.db())
            throw HTTPError(.tooManyRequests, message: "Too many attempts. Please request a new code.")
        }
        
        // Verify code
        if verificationCode.code != verifyRequest.code {
            verificationCode.incrementAttempts()
            try await verificationCode.save(on: fluent.db())
            throw HTTPError(.badRequest, message: "Invalid verification code")
        }
        
        // Mark email as verified
        user.emailVerified = true
        try await user.save(on: fluent.db())
        
        // Delete verification code
        try await verificationCode.delete(on: fluent.db())
        
        // Generate tokens
        let expiresIn = Int(jwtConfig.accessTokenExpiration)
        let accessExpirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date(timeIntervalSinceNow: jwtConfig.refreshTokenExpiration)
        let issuedAt = Date()
        
        // Create access token payload
        let accessPayload = JWTPayloadData(
            subject: .init(value: try user.requireID().uuidString),
            expiration: .init(value: accessExpirationDate),
            type: "access",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        // Create refresh token payload
        let refreshPayload = JWTPayloadData(
            subject: .init(value: try user.requireID().uuidString),
            expiration: .init(value: refreshExpirationDate),
            type: "refresh",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        // Sign tokens
        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let refreshToken = try await self.jwtKeyCollection.sign(refreshPayload, kid: self.kid)
        
        // Create necessary records
        await createTokenOnSuccessfulAuthentication(
            user: user,
            request: request,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessPayload: accessPayload,
            refreshPayload: refreshPayload,
            accessExpirationDate: accessExpirationDate,
            refreshExpirationDate: refreshExpirationDate,
            context: context
        )
        
        let dateFormatter = ISO8601DateFormatter()
        return .init(
            status: .ok,
            response: AuthResponse(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: "Bearer",
                expiresIn: UInt(expiresIn),
                expiresAt: dateFormatter.string(from: accessExpirationDate),
                user: UserResponse(from: user),
                status: AuthResponse.STATUS_SUCCESS
            )
        )
    }
    
    /// Generate a state token for multi-step auth flow
    private func generateStateToken(for user: User) async throws -> String {
        // Generate temporary token for auth flow state
        let stateTokenPayload = JWTPayloadData(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: Date(timeIntervalSinceNow: 600)), // 10 minutes
            type: "state_token",  // Use a generic state token type for MFA flow
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: Date(),
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        return try await self.jwtKeyCollection.sign(stateTokenPayload, kid: self.kid)
    }
    
    /// Revoke a specific token
    @Sendable func revokeAccessToken(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Ensure user is authenticated
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        // Decode the request
        let revokeRequest = try await request.decode(as: RevokeTokenRequest.self, context: context)
        
        do {
            // Verify the token to get its expiration
            let payload = try await self.jwtKeyCollection.verify(revokeRequest.token, as: JWTPayloadData.self)
            
            // Ensure the token belongs to the current user
            guard payload.subject.value == user.id?.uuidString else {
                throw HTTPError(.forbidden, message: "Cannot revoke token belonging to another user")
            }
            
            // Add token to blacklist
            await tokenStore.blacklist(revokeRequest.token, expiresAt: payload.expiration.value, reason: .userRevoked)
            
            return .init(
                status: .ok,
                response: MessageResponse(
                    message: "Token revoked successfully",
                    success: true
                )
            )
        } catch let error as JWTError {
            // Handle JWT verification errors
            throw HTTPError(.badRequest, message: "Invalid token: \(error.localizedDescription)")
        }
    }
    
    /// Verify email MFA during sign-in
    @Sendable func verifyEmailMFASignIn(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        let verifyRequest = try await request.decode(as: EmailSignInVerifyRequest.self, context: context)
        
        // Verify and decode temporary token
        let tempTokenPayload = try await self.jwtKeyCollection.verify(verifyRequest.stateToken, as: JWTPayloadData.self)
        
        // Ensure it's an appropriate token type
        guard tempTokenPayload.type == "state_token" else {
            throw HTTPError(.unauthorized, message: "Invalid token type")
        }
        
        // Get user from database
        guard let user = try await User.find(UUID(uuidString: tempTokenPayload.subject.value), on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "User not found")
        }
        
        // Verify token version
        guard let tokenVersion = tempTokenPayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }
        
        // Check if account is locked
        if user.isLocked() {
            if let until = user.lockoutUntil {
                throw HTTPError(.unauthorized, message: "Account is locked. Try again after \(until)")
            }
            throw HTTPError(.unauthorized, message: "Account is locked")
        }
        
        // Verify the code
        guard let verificationCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, try user.requireID())
            .filter(\.$code, .equal, verifyRequest.code)
            .filter(\.$type, .equal, "mfa_sign_in")
            .first() else {
            // Increment failed attempts
            user.incrementFailedSignInAttempts()
            try await user.save(on: fluent.db())
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Code is valid - check for expiration
        if verificationCode.isExpired {
            try await verificationCode.delete(on: fluent.db())
            throw HTTPError(.unauthorized, message: "Verification code has expired")
        }
        
        // Delete the code once used
        try await verificationCode.delete(on: fluent.db())
        
        // Reset failed attempts if needed
        if user.failedSignInAttempts > 0 {
            user.resetFailedSignInAttempts()
            try await user.save(on: fluent.db())
        }
        
        // Complete sign in by creating tokens
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
        
        // Creates necessary records after successful authentication
        // - Parameters:
        //   - user: The authenticated user
        //   - request: The HTTP request
        //   - accessToken: The JWT access token
        //   - refreshToken: The JWT refresh token
        //   - accessPayload: The access token payload
        //   - refreshPayload: The refresh token payload
        //   - accessExpirationDate: Expiration date for the access token
        //   - refreshExpirationDate: Expiration date for the refresh token
        //   - context: Request context
        await createTokenOnSuccessfulAuthentication(
            user: user,
            request: request,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessPayload: accessPayload,
            refreshPayload: refreshPayload,
            accessExpirationDate: accessExpirationDate,
            refreshExpirationDate: refreshExpirationDate,
            context: context
        )
        
        let dateFormatter = ISO8601DateFormatter()
        return .init(
            status: .ok,
            response: AuthResponse(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: "Bearer",
                expiresIn: UInt(expiresIn),
                expiresAt: dateFormatter.string(from: accessExpirationDate),
                user: UserResponse(from: user),
                status: AuthResponse.STATUS_SUCCESS
            )
        )
    }
    
    /// Resend verification email for initial email verification
    @Sendable func resendVerificationEmail(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Get email from request
        let resendRequest = try await request.decode(as: ResendVerificationRequest.self, context: context)
        
        // Find user
        guard let user = try await User.query(on: fluent.db())
            .filter(\.$email, .equal, resendRequest.email)
            .first() else {
            throw HTTPError(.notFound, message: "User not found")
        }
        
        // Check if already verified
        if user.emailVerified {
            throw HTTPError(.badRequest, message: "Email is already verified")
        }
        
        // Delete any existing verification codes
        let userID = try user.requireID()
        try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "email_verify")
            .delete()
        
        // Generate and store new code
        let code = EmailVerificationCode.generateCode()
        let verificationCode = EmailVerificationCode(
            userID: userID,
            code: code,
            type: "email_verify",
            expiresAt: Date().addingTimeInterval(300) // 5 minutes
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send verification email
        try await emailService.sendVerificationEmail(to: user.email, code: code)
        
        context.logger.info("Resent verification email to user: \(user.email)")
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification email sent",
                success: true
            )
        )
    }
    
    /// Get verification status for initial email verification
    @Sendable func getVerificationStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<EmailVerificationStatusResponse> {
        guard let user = context.identity else {
            context.logger.notice("Unauthorized attempt to get verification status")
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        context.logger.info("Getting verification status for user: \(user.email)")
        
        return .init(
            status: .ok,
            response: EmailVerificationStatusResponse(
                enabled: user.emailVerified,
                verified: user.emailVerified
            )
        )
    }
    
    /// Get email verification status
    @Sendable func getEmailVerificationStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<EmailVerificationStatusResponse> {
        guard let user = context.identity else {
            context.logger.notice("Unauthorized attempt to get email verification status")
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        context.logger.info("Getting email verification status for user: \(user.email)")
        
        return .init(
            status: .ok,
            response: EmailVerificationStatusResponse(
                enabled: user.emailVerified,
                verified: user.emailVerified
            )
        )
    }
    
    /// Get available MFA methods for the user
    @Sendable func getMFAMethods(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MFAMethodsResponse> {
        guard let user = context.identity else {
            context.logger.notice("Unauthorized attempt to get MFA methods")
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        context.logger.info("Getting MFA methods for user: \(user.email)")
        
        return .init(
            status: .ok,
            response: MFAMethodsResponse(
                emailMFAEnabled: user.emailMFAEnabled,
                totpMFAEnabled: user.totpMFAEnabled
            )
        )
    }
    
    /// Send MFA email verification code
    @Sendable func sendEmailMFASignIn(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        return try await requestEmailCode(request, context: context)
    }
    
    /// Resend MFA email verification code
    @Sendable func resendEmailMFASignIn(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        return try await requestEmailCode(request, context: context)
    }
    
    // MARK: - TOTP MFA Forwarding
    
    @Sendable func enableTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<TOTPEnableResponse> {
        try await totpController.enableTOTP(request, context: context)
    }
    
    @Sendable func verifyTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<TOTPVerifyResponse> {
        try await totpController.verifyTOTP(request, context: context)
    }
    
    @Sendable func disableTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        try await totpController.disableTOTP(request, context: context)
    }
    
    @Sendable func getTOTPStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<TOTPStatusResponse> {
        try await totpController.getTOTPStatus(request, context: context)
    }
    
    // MARK: - Email MFA Forwarding
    
    @Sendable func enableEmailMFA(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        try await emailVerificationController.enableEmailMFA(request, context: context)
    }
    
    @Sendable func verifyEmailMFA(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<EmailMFAVerifyResponse> {
        try await emailVerificationController.verifyEmailMFA(request, context: context)
    }
    
    @Sendable func disableEmailMFA(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        try await emailVerificationController.disableEmailMFA(request, context: context)
    }
    
    @Sendable func getEmailMFAStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<EmailMFAVerificationStatusResponse> {
        try await emailVerificationController.getEmailMFAStatus(request, context: context)
    }
    
    /// Select MFA method to use during sign-in
    /// 
    /// This endpoint allows users to choose which MFA method they want to use to complete sign-in.
    /// This follows industry standard practices used by major authentication providers.
    /// 
    /// Request body must include:
    /// - stateToken: The token received from the initial sign-in attempt
    /// - method: The MFA method to use (either "totp" or "email")
    /// 
    /// The response will provide the next steps based on the selected method.
    @Sendable func selectMFAMethod(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // Decode MFA selection request
        let selectionRequest = try await request.decode(as: MFASelectionRequest.self, context: context)
        
        // Verify and decode state token
        let statePayload = try await self.jwtKeyCollection.verify(selectionRequest.stateToken, as: JWTPayloadData.self)
        
        // Get user from database
        guard let userID = UUID(uuidString: statePayload.subject.value),
              let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "Invalid token")
        }
        
        // Verify token version
        guard let tokenVersion = statePayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }
        
        // Check the selected method is actually enabled for the user
        switch selectionRequest.method {
        case .totp:
            if !user.totpMFAEnabled {
                throw HTTPError(.badRequest, message: "TOTP is not enabled for this account")
            }
            
            return .init(
                status: .ok,
                response: AuthResponse(
                    stateToken: selectionRequest.stateToken,
                    status: AuthResponse.STATUS_MFA_TOTP_REQUIRED,
                    maskedEmail: user.email.maskEmail()
                )
            )
            
        case .email:
            if !user.emailVerified {
                throw HTTPError(.badRequest, message: "Email MFA is not enabled for this account")
            }
            
            return .init(
                status: .ok,
                response: AuthResponse(
                    tokenType: "Bearer",
                    stateToken: selectionRequest.stateToken,
                    status: AuthResponse.STATUS_MFA_EMAIL_REQUIRED,
                    maskedEmail: user.email.maskEmail()
                )
            )
        }
    }
    
    /// Cancel an in-progress authentication flow
    /// Terminates a session with a stateToken and invalidates the token
    /// - Parameters:
    ///   - request: The HTTP request with the stateToken
    ///   - context: The application request context
    /// - Returns: A success message if the cancellation was successful
    @Sendable func cancelAuthentication(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Decode the cancellation request
        struct CancelAuthRequest: Codable {
            let stateToken: String
        }
        
        let cancelRequest = try await request.decode(as: CancelAuthRequest.self, context: context)
        
        do {
            // Verify and decode state token to get expiration and user info
            let stateTokenPayload = try await self.jwtKeyCollection.verify(cancelRequest.stateToken, as: JWTPayloadData.self)
            
            // Ensure it's a state token
            guard stateTokenPayload.type == "state_token" || stateTokenPayload.type == "email_verification" else {
                throw HTTPError(.badRequest, message: "Invalid token type")
            }
            
            // Blacklist the token
            await tokenStore.blacklist(
                cancelRequest.stateToken, 
                expiresAt: stateTokenPayload.expiration.value, 
                reason: .authenticationCancelled
            )
            
            context.logger.info("Authentication flow cancelled with state token")
            
            return .init(
                status: .ok,
                response: MessageResponse(
                    message: "Authentication cancelled successfully",
                    success: true
                )
            )
        } catch let error as JWTError {
            // Handle JWT validation errors
            context.logger.warning("Failed to cancel authentication: \(error.localizedDescription)")
            
            switch error.errorType {
            case .claimVerificationFailure:
                // Token is expired - no need to cancel it
                return .init(
                    status: .ok,
                    response: MessageResponse(
                        message: "Token already expired",
                        success: true
                    )
                )
            default:
                throw HTTPError(.badRequest, message: "Invalid state token")
            }
        }
    }
    
    /// Creates a token record in the database for JWT tokens
    /// - Parameters:
    ///   - accessToken: The access token string
    ///   - refreshToken: The refresh token string
    ///   - accessJti: JWT ID of the access token
    ///   - refreshJti: JWT ID of the refresh token
    ///   - accessExpirationDate: Expiration date for access token
    ///   - refreshExpirationDate: Expiration date for refresh token
    ///   - sessionId: Session ID to associate with the token
    /// - Returns: The created token record
    private func createTokenRecord(
        accessToken: String,
        refreshToken: String,
        accessJti: String,
        refreshJti: String,
        accessExpirationDate: Date,
        refreshExpirationDate: Date,
        sessionId: UUID
    ) async throws -> Token {
        // Create token record with default values for new generation
        let token = Token(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: accessExpirationDate,
            refreshTokenExpiresAt: refreshExpirationDate,
            jti: refreshJti,  // Use refresh token JTI as primary JTI
            parentJti: nil,   // No parent for first generation
            familyId: UUID(), // New family for first token
            generation: 0,    // First generation
            sessionId: sessionId
        )
        
        try await token.save(on: fluent.db())
        return token
    }
    
    /// Get the JSON Web Key Set (JWKS) containing the public keys used for token verification
    /// This endpoint follows the OAuth 2.0 and OpenID Connect standards
    @Sendable func getJWKS(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<JWKSResponse> {
        // Get the JWKS data from the key collection
        let jwks = try await self.jwtKeyCollection.jwks()
        
        return .init(
            status: .ok,
            response: jwks
        )
    }
    
    /// Get the OpenID Connect UserInfo response for the authenticated user
    /// This endpoint follows the OpenID Connect Core 1.0 specification
    /// https://openid.net/specs/openid-connect-core-1_0.html#UserInfo
    @Sendable func getUserInfo(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserInfoResponse> {
        // Ensure user is authenticated
        guard let user = context.identity else {
            throw HTTPError(.unauthorized, message: "Authentication required")
        }
        
        // Create UserInfo response
        let userInfo = UserInfoResponse(from: user)
        
        return .init(
            status: .ok,
            response: userInfo
        )
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

extension MessageResponse: ResponseEncodable {}

/// Request structure for changing a password
struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
    
    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

/// Request structure for initiating a password reset
struct ForgotPasswordRequest: Codable {
    let email: String
    
    enum CodingKeys: String, CodingKey {
        case email
    }
}

/// Request structure for completing a password reset
struct ResetPasswordRequest: Codable {
    let email: String
    let code: String
    let newPassword: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case code
        case newPassword = "new_password"
    }
}

/// Request structure for token revocation
struct RevokeTokenRequest: Codable {
    let token: String
}

/// Request structure for email-based sign in verification
struct EmailSignInVerifyRequest: Codable {
    let stateToken: String
    let code: String
    
    enum CodingKeys: String, CodingKey {
        case stateToken = "state_token"
        case code
    }
}

/// Simple message response structure
struct MessageResponse: Codable {
    let message: String
    let success: Bool
}

/// Response structure for email verification status
struct EmailVerificationStatusResponse: Codable {
    let enabled: Bool
    let verified: Bool
}

extension EmailVerificationStatusResponse: ResponseEncodable {}

/// Response structure for TOTP MFA status
struct TOTPMFAStatusResponse: Codable {
    let enabled: Bool
}

extension TOTPMFAStatusResponse: ResponseEncodable {}
