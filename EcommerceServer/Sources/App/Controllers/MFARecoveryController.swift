import Foundation
import Hummingbird
import HummingbirdFluent
import CryptoKit
import HummingbirdBcrypt
import NIOCore
import FluentKit
import JWTKit

/// Controller for managing MFA recovery codes
struct MFARecoveryController {
    typealias Context = AppRequestContext
    private let fluent: Fluent
    private let emailService: EmailService
    private let jwtConfig: JWTConfiguration
    private let jwtKeyCollection: JWTKeyCollection
    private let kid: JWKIdentifier
    private let tokenStore: TokenStore
    
    // Constants
    private let minRemainingCodes = 2  // Prompt regeneration when this many or fewer remain
    private let codeValidityDays = 365 // Recovery codes expire after 1 year
    
    init(
        fluent: Fluent,
        emailService: EmailService,
        jwtConfig: JWTConfiguration,
        jwtKeyCollection: JWTKeyCollection,
        kid: JWKIdentifier,
        tokenStore: TokenStore
    ) {
        self.fluent = fluent
        self.emailService = emailService
        self.jwtConfig = jwtConfig
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.tokenStore = tokenStore
    }
    
    /// Add protected routes for recovery code management
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.post("generate", use: generateRecoveryCodes)
            .get("list", use: listRecoveryCodes)
            .get("status", use: getRecoveryCodesStatus)
            .post("regenerate", use: regenerateRecoveryCodes)
    }
    
    /// Add public routes for recovery code verification
    func addPublicRoutes(to group: RouterGroup<Context>) {
        group.post("verify", use: verifyRecoveryCode)
    }
    
    /// Generate new recovery codes for a user
    /// This invalidates any existing recovery codes (used or unused)
    @Sendable func generateRecoveryCodes(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<RecoveryCodesResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Ensure user has MFA enabled
        guard user.totpMFAEnabled || user.emailMFAEnabled else {
            throw HTTPError(.badRequest, message: "MFA must be enabled to generate recovery codes")
        }
        
        let userID = try user.requireID()
        
        do {
            // Delete ALL existing recovery codes (used and unused)
            try await MFARecoveryCode.query(on: fluent.db())
                .filter(\.$user.$id, .equal, userID)
                .delete()
            
            // Generate new codes
            let plainCodes = MFARecoveryCode.generateCodes()
            let expirationDate = Date().addingTimeInterval(TimeInterval(codeValidityDays * 24 * 60 * 60))
            
            // Store hashed codes
            for code in plainCodes {
                let hashedCode = try MFARecoveryCode.hashCode(code)
                let recoveryCode = MFARecoveryCode(
                    userID: userID,
                    code: hashedCode,
                    expiresAt: expirationDate
                )
                try await recoveryCode.save(on: fluent.db())
            }
            
            // Send notification email
            try await emailService.sendRecoveryCodesGeneratedEmail(to: user.email)
            
            return .init(
                status: .created,
                response: RecoveryCodesResponse(
                    codes: plainCodes,
                    message: "Store these recovery codes in a safe place. They cannot be shown again and will expire in \(codeValidityDays) days.",
                    expiresAt: expirationDate.ISO8601Format()
                )
            )
        } catch let error as RecoveryCodeError {
            throw HTTPError(.badRequest, message: error.description)
        } catch {
            context.logger.error("Failed to generate recovery codes: \(error)")
            throw HTTPError(.internalServerError, message: "Failed to generate recovery codes")
        }
    }
    
    /// List all recovery codes for a user (showing only if they're used)
    @Sendable func listRecoveryCodes(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<RecoveryCodesStatusResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        let userID = try user.requireID()
        
        // Get all recovery codes
        let codes = try await MFARecoveryCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .all()
        
        let totalCodes = codes.count
        let usedCodes = codes.filter { $0.used }.count
        let remainingCodes = totalCodes - usedCodes
        let expiredCodes = codes.filter { !$0.used && ($0.isExpired) }.count
        let validCodes = remainingCodes - expiredCodes
        
        // Check if user should regenerate codes
        let shouldRegenerate = validCodes <= minRemainingCodes
        
        return .init(
            status: .ok,
            response: RecoveryCodesStatusResponse(
                totalCodes: totalCodes,
                usedCodes: usedCodes,
                remainingCodes: remainingCodes,
                expiredCodes: expiredCodes,
                validCodes: validCodes,
                shouldRegenerate: shouldRegenerate,
                nextExpirationDate: codes.filter { !$0.used && !$0.isExpired }
                    .compactMap { $0.expiresAt }
                    .min()?
                    .ISO8601Format()
            )
        )
    }
    
    /// Verify a recovery code during sign in
    @Sendable func verifyRecoveryCode(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // Decode verification request
        let verifyRequest = try await request.decode(as: RecoveryCodeVerifyRequest.self, context: context)
        
        // Verify and decode state token
        let stateTokenPayload = try await self.jwtKeyCollection.verify(verifyRequest.stateToken, as: JWTPayloadData.self)
        
        // Ensure it's a state token
        guard stateTokenPayload.type == "state_token" else {
            throw HTTPError(.unauthorized, message: "Invalid token type")
        }
        
        // Get user from database
        guard let userID = UUID(uuidString: stateTokenPayload.subject.value),
              let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "User not found")
        }
        
        // Verify token version
        guard let tokenVersion = stateTokenPayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }
        
        do {
            // Find an unused recovery code that matches
            let codes = try await MFARecoveryCode.query(on: fluent.db())
                .filter(\.$user.$id, .equal, userID)
                .filter(\.$used, .equal, false)
                .all()
            
            // Try each code and handle specific errors
            for recoveryCode in codes {
                do {
                    if try recoveryCode.verifyCode(verifyRequest.code) {
                        // Get client info
                        let forwardedFor = request.headers[values: .init("X-Forwarded-For")!].first ?? "unknown"
                        let userAgent = request.headers[values: .userAgent].first ?? "unknown"
                        
                        // Mark the code as used with client info
                        recoveryCode.markAsUsed(fromIP: forwardedFor, userAgent: userAgent)
                        try await recoveryCode.save(on: fluent.db())
                        
                        // Send notification email about used recovery code
                        try await emailService.sendRecoveryCodeUsedEmail(
                            to: user.email,
                            ip: forwardedFor,
                            userAgent: userAgent
                        )
                        
                        // Generate tokens for successful authentication
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
                        
                        // Create session and token records
                        let session = try await createSessionRecord(
                            userID: userID,
                            request: request,
                            tokenID: accessPayload.id,
                            context: context
                        )
                        
                        if let sessionId = session.id {
                            _ = try await createTokenRecord(
                                accessToken: accessToken,
                                refreshToken: refreshToken,
                                accessJti: accessPayload.id,
                                refreshJti: refreshPayload.id,
                                accessExpirationDate: accessExpirationDate,
                                refreshExpirationDate: refreshExpirationDate,
                                sessionId: sessionId
                            )
                        }
                        
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
                } catch RecoveryCodeError.expired {
                    continue // Try next code
                } catch RecoveryCodeError.tooManyAttempts {
                    continue // Try next code
                } catch RecoveryCodeError.alreadyUsed {
                    continue // Try next code
                } catch RecoveryCodeError.invalidFormat {
                    throw HTTPError(.badRequest, message: "Invalid or expired recovery code format")
                } catch {
                    throw HTTPError(.internalServerError, message: "Error verifying recovery code")
                }
            }
            
            // If we get here, no valid code was found
            throw HTTPError(.badRequest, message: "Invalid or expired recovery code")
        } catch let error as HTTPError {
            throw error
        } catch {
            context.logger.error("Failed to verify recovery code: \(error)")
            throw HTTPError(.internalServerError, message: "Failed to verify recovery code")
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
        let forwardedFor = request.headers[values: .init("X-Forwarded-For")!].first ?? "unknown"
        let userAgent = request.headers[values: .userAgent].first ?? "unknown"
        
        let session = Session(
            userID: userID,
            deviceName: "Recovery Code Sign In",
            ipAddress: forwardedFor,
            userAgent: userAgent,
            tokenId: tokenID,
            isActive: true
        )
        
        try await session.save(on: fluent.db())
        return session
    }
    
    /// Creates a token record for tracking token usage and rotation
    /// - Parameters:
    ///   - accessToken: The access token
    ///   - refreshToken: The refresh token
    ///   - accessJti: Access token JTI
    ///   - refreshJti: Refresh token JTI
    ///   - accessExpirationDate: Access token expiration date
    ///   - refreshExpirationDate: Refresh token expiration date
    ///   - sessionId: Associated session ID
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
        let token = Token(
            accessToken: accessToken,
            refreshToken: refreshToken,
            accessTokenExpiresAt: accessExpirationDate,
            refreshTokenExpiresAt: refreshExpirationDate,
            jti: refreshJti,
            parentJti: nil,
            familyId: UUID(),
            generation: 0,
            sessionId: sessionId
        )
        
        try await token.save(on: fluent.db())
        return token
    }
    
    /// Regenerate recovery codes with password verification
    @Sendable func regenerateRecoveryCodes(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<RecoveryCodesResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Verify password before allowing regeneration
        let regenerateRequest = try await request.decode(as: RegenerateCodesRequest.self, context: context)
        
        guard let passwordHash = user.passwordHash else {
            throw HTTPError(.internalServerError, message: "Account configuration error")
        }
        
        let passwordValid = Bcrypt.verify(regenerateRequest.password, hash: passwordHash)
        
        if !passwordValid {
            throw HTTPError(.unauthorized, message: "Invalid password")
        }
        
        // Generate new codes
        return try await generateRecoveryCodes(request, context: context)
    }
    
    /// Get recovery codes status
    @Sendable func getRecoveryCodesStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<RecoveryMFAStatusResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        let userID = try user.requireID()
        
        // Check if user has any valid recovery codes
        let hasValidCodes = try await MFARecoveryCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$used, .equal, false)
            .filter(\.$expiresAt, .greaterThan, Date())
            .count() > 0
        
        // MFA status is independent of recovery codes status
        let mfaEnabled = user.totpMFAEnabled || user.emailMFAEnabled
        
        return .init(
            status: .ok,
            response: RecoveryMFAStatusResponse(
                enabled: mfaEnabled,
                hasValidCodes: hasValidCodes
            )
        )
    }
}

// MARK: - Request/Response Types

struct RecoveryCodeVerifyRequest: Codable {
    let code: String
    let stateToken: String
    
    enum CodingKeys: String, CodingKey {
        case code
        case stateToken = "state_token"
    }
}

struct RegenerateCodesRequest: Codable {
    let password: String
}

struct RecoveryCodesResponse: Codable {
    let codes: [String]
    let message: String
    let expiresAt: String
    
    enum CodingKeys: String, CodingKey {
        case codes
        case message
        case expiresAt = "expires_at"
    }
}

struct RecoveryCodesStatusResponse: Codable {
    let totalCodes: Int
    let usedCodes: Int
    let remainingCodes: Int
    let expiredCodes: Int
    let validCodes: Int
    let shouldRegenerate: Bool
    let nextExpirationDate: String?
    
    enum CodingKeys: String, CodingKey {
        case totalCodes = "total_codes"
        case usedCodes = "used_codes"
        case remainingCodes = "remaining_codes"
        case expiredCodes = "expired_codes"
        case validCodes = "valid_codes"
        case shouldRegenerate = "should_regenerate"
        case nextExpirationDate = "next_expiration_date"
    }
}

struct RecoveryMFAStatusResponse: Codable {
    let enabled: Bool
    let hasValidCodes: Bool
    
    enum CodingKeys: String, CodingKey {
        case enabled
        case hasValidCodes = "has_valid_codes"
    }
}

extension RecoveryCodesResponse: ResponseEncodable {}
extension RecoveryCodesStatusResponse: ResponseEncodable {}
extension RecoveryMFAStatusResponse: ResponseEncodable {} 
