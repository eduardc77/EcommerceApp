import Foundation
import Hummingbird
import HummingbirdFluent
import HummingbirdBcrypt
import HTTPTypes

/// Controller for managing  Email MFA
struct EmailMFAController {
    typealias Context = AppRequestContext
    let fluent: HummingbirdFluent.Fluent
    let emailService: EmailService
    let mfaService: MFAService
    
    init(fluent: HummingbirdFluent.Fluent, emailService: EmailService, mfaService: MFAService) {
        self.fluent = fluent
        self.emailService = emailService
        self.mfaService = mfaService
    }
    
    /// Add protected routes for email verification (MFA)
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.post("enable", use: enableEmailMFA)
            .post("verify", use: verifyEmailMFA)
            .post("disable", use: disableEmailMFA)
            .post("resend", use: resendEmailMFACode)
            .get("status", use: getEmailMFAStatus)
    }
    
    /// Send verification code for enabling email MFA
    @Sendable func enableEmailMFA(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Get user ID
        let userID = try user.requireID()
        
        // Check for existing verification code and cooldown
        if let existingCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "mfa_enable")
            .first() {
            
            // Check if within cooldown period
            if existingCode.isWithinCooldown {
                let remaining = existingCode.remainingCooldown
                var headers = HTTPFields()
                headers.append(HTTPField(name: HTTPField.Name("Retry-After")!, value: "\(remaining)"))
                throw HTTPError(
                    .tooManyRequests,
                    headers: headers,
                    message: "Please wait \(remaining) seconds before requesting another code"
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
            type: "mfa_enable",
            expiresAt: Date().addingTimeInterval(300) // 5 minutes
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send verification email
        try await emailService.sendVerificationEmail(to: user.email, code: code)
        
        context.logger.info("Sent verification code to user: \(user.email)")
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification code sent to your email",
                success: true
            )
        )
    }
    
    /// Verify email MFA code
    @Sendable func verifyEmailMFA(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<EmailMFAVerifyResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Ensure email is verified before allowing MFA enable
        guard user.emailVerified else {
            throw HTTPError(.badRequest, message: "Email must be verified before enabling MFA")
        }
        
        // Decode verification request
        let verifyRequest = try await request.decode(as: EmailMFAVerifyRequest.self, context: context)
        
        // Get user ID first
        let userID = try user.requireID()
        
        // Find the most recent verification code
        guard let verificationCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "mfa_enable")
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
        
        // Verify the code
        if verificationCode.code != verifyRequest.code {
            verificationCode.incrementAttempts()
            try await verificationCode.save(on: fluent.db())
            throw HTTPError(.badRequest, message: "Invalid verification code")
        }
        
        // Delete the verification code
        try await verificationCode.delete(on: fluent.db())
        
        // Check if any MFA method was already enabled before this one
        let wasMFAAlreadyEnabled = user.totpMFAEnabled || user.emailMFAEnabled
        
        // Enable email MFA and invalidate tokens
        user.emailMFAEnabled = true
        user.tokenVersion += 1
        
        try await user.save(on: fluent.db())
        
        // Generate recovery codes only if this is the first MFA method being enabled
        let recoveryCodes = wasMFAAlreadyEnabled ? nil : try await mfaService.generateRecoveryCodes(for: user)
        
        return .init(
            status: .ok,
            response: EmailMFAVerifyResponse(
                message: "Email MFA enabled successfully",
                success: true,
                recoveryCodes: recoveryCodes
            )
        )
    }
    
    /// Disable email verification
    @Sendable func disableEmailMFA(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Check if already disabled
        if !user.emailMFAEnabled {
            return .init(
                status: .badRequest,
                response: MessageResponse(
                    message: "Email MFA is not enabled",
                    success: false
                )
            )
        }
        
        // Get disable request with password
        let disableRequest: DisableEmailMFARequest
        do {
            disableRequest = try await request.decode(as: DisableEmailMFARequest.self, context: context)
        } catch {
            throw HTTPError(.badRequest, message: "Password verification required")
        }
        
        // Verify password
        guard let passwordHash = user.passwordHash else {
            context.logger.error("User \(user.email) has no password hash")
            throw HTTPError(.internalServerError, message: "Account configuration error. Please contact support.")
        }
        
        // Perform password verification
        let passwordValid = Bcrypt.verify(disableRequest.password, hash: passwordHash)
        
        if !passwordValid {
            throw HTTPError(.unauthorized, message: "Invalid password")
        }
        
        // Disable email MFA
        user.emailMFAEnabled = false
        try await user.save(on: fluent.db())
        
        // Let the MFA service handle recovery codes if needed
        try await mfaService.handleMFADisabled(for: user)
        
        return .init(
            response: MessageResponse(
                message: "Multi-Factor Email Authentication disabled successfully",
                success: true
            )
        )
    }
    
    /// Get email verification status
    @Sendable func getEmailMFAStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<EmailMFAVerificationStatusResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        return .init(
            status: .ok,
            response: EmailMFAVerificationStatusResponse(
                emailMFAEnabled: user.emailMFAEnabled,
                emailVerified: user.emailVerified
            )
        )
    }
    
    /// Resend email MFA verification code during setup
    @Sendable func resendEmailMFACode(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Get user ID
        let userID = try user.requireID()
        
        // Check for existing verification code and cooldown
        if let existingCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "mfa_enable")
            .first() {
            
            // Check if within cooldown period
            if existingCode.isWithinCooldown {
                let remaining = existingCode.remainingCooldown
                var headers = HTTPFields()
                headers.append(HTTPField(name: HTTPField.Name("Retry-After")!, value: "\(remaining)"))
                throw HTTPError(
                    .tooManyRequests,
                    headers: headers,
                    message: "Please wait \(remaining) seconds before requesting another code"
                )
            }
            
            // Delete the existing code since it might be expired
            try await existingCode.delete(on: fluent.db())
        }
        
        // Generate a new code
        let code = EmailVerificationCode.generateCode()
        let verificationCode = EmailVerificationCode(
            userID: userID,
            code: code,
            type: "mfa_enable",
            expiresAt: Date().addingTimeInterval(300) // 5 minutes
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send verification email
        try await emailService.sendMFASetupEmail(to: user.email, code: code)
        
        context.logger.info("Resent MFA setup verification code to user: \(user.email)")
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification code sent to your email",
                success: true
            )
        )
    }
}

/// Request for email verification
struct EmailVerifyRequest: Codable {
    let email: String
    let code: String
}

/// Request for resending verification email
struct ResendVerificationRequest: Codable {
    let email: String
}

/// Response for email verification status
struct EmailMFAVerificationStatusResponse: Codable {
    let emailMFAEnabled: Bool
    let emailVerified: Bool
    
    enum CodingKeys: String, CodingKey {
        case emailMFAEnabled = "email_mfa_enabled"
        case emailVerified = "email_verified"
    }
}

struct EmailMFAVerifyRequest: Codable {
    let code: String
}

struct EmailMFAVerifyResponse: Codable {
    let message: String
    let success: Bool
    let recoveryCodes: [String]?
}

extension EmailMFAVerificationStatusResponse: ResponseEncodable {}
extension EmailMFAVerifyResponse: ResponseEncodable {}
