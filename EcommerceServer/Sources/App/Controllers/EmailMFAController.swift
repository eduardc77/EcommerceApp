import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import HTTPTypes

/// Controller for managing  Email MFA
struct EmailMFAController {
    typealias Context = AppRequestContext
    let fluent: HummingbirdFluent.Fluent
    let emailService: EmailService
    
    init(fluent: HummingbirdFluent.Fluent, emailService: EmailService) {
        self.fluent = fluent
        self.emailService = emailService
    }
    
    /// Add protected routes for email verification (MFA)
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.post("enable", use: enableEmailMFA)
            .post("verify", use: verifyEmailMFA)
            .post("disable", use: disableEmailMFA)
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
        
        // Delete any existing verification codes for this user
        let userID = try user.requireID()
        try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "mfa_setup")
            .delete()
        
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
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Ensure email is verified before allowing MFA setup
        guard user.emailVerified else {
            throw HTTPError(.badRequest, message: "Email must be verified before enabling MFA")
        }
        
        // Decode verification request
        let verifyRequest = try await request.decode(as: EmailVerifyRequest.self, context: context)
        
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
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Delete the verification code
        try await verificationCode.delete(on: fluent.db())
        
        // Enable email-based MFA only when explicitly requested
        user.emailVerificationEnabled = true
        user.tokenVersion += 1  // Increment token version to invalidate all existing tokens
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Two-factor authentication enabled successfully",
                success: true
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
        if !user.emailVerificationEnabled {
            return .init(
                status: .badRequest,
                response: MessageResponse(
                    message: "Email verification is not enabled",
                    success: false
                )
            )
        }
        
        // Get user ID first
        let userID = try user.requireID()
        
        // Find the most recent verification code
        guard let verificationCode = try await EmailVerificationCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, userID)
            .filter(\.$type, .equal, "mfa_setup")
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
        guard let code = request.headers.first(where: { $0.name.canonicalName == "x-email-code" })?.value else {
            throw HTTPError(.badRequest, message: "Verification code is required")
        }
        
        if verificationCode.code != code {
            verificationCode.incrementAttempts()
            try await verificationCode.save(on: fluent.db())
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Delete the verification code
        try await verificationCode.delete(on: fluent.db())
        
        // Disable email verification
        user.emailVerificationEnabled = false
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Email verification disabled successfully",
                success: true
            )
        )
    }
    
    /// Get email verification status
    @Sendable func getEmailMFAStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MFAEmailVerificationStatusResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        return .init(
            status: .ok,
            response: MFAEmailVerificationStatusResponse(
                enabled: user.emailVerificationEnabled,
                verified: user.emailVerified
            )
        )
    }
    
    /// Resend initial email verification code
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
            expiresAt: Date().addingTimeInterval(300)
        )
        try await verificationCode.save(on: fluent.db())
        
        // Send verification email
        try await emailService.sendVerificationEmail(to: user.email, code: code)
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification email sent",
                success: true
            )
        )
    }
    
    /// Send initial verification email after registration
    @Sendable func sendInitialVerificationEmail(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Get email from request
        let sendRequest = try await request.decode(as: ResendVerificationRequest.self, context: context)
        
        // Find user
        guard let user = try await User.query(on: fluent.db())
            .filter(\.$email, .equal, sendRequest.email)
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
        
        context.logger.info("Sent initial verification email to user: \(user.email)")
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Verification email sent",
                success: true
            )
        )
    }
}

/// Request for verifying email code
struct EmailVerifyRequest: Codable {
    let email: String
    let code: String
}

/// Request for resending verification email
struct ResendVerificationRequest: Codable {
    let email: String
}

/// Response for email verification status
struct MFAEmailVerificationStatusResponse: Codable {
    let enabled: Bool
    let verified: Bool
}

extension MFAEmailVerificationStatusResponse: ResponseEncodable {}
