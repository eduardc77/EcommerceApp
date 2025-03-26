import Foundation
import Hummingbird
import HummingbirdOTP
import HummingbirdFluent
import HummingbirdBcrypt

/// Controller for managing TOTP (Time-based One-Time Password) functionality
struct TOTPController {
    typealias Context = AppRequestContext
    let fluent: Fluent
    
    init(fluent: Fluent) {
        self.fluent = fluent
    }
    
    /// Add protected routes for TOTP management
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.post("enable", use: enableTOTP)
            .post("verify", use: verifyTOTP)
            .post("disable", use: disableTOTP)
            .get("status", use: getTOTPStatus)
    }
    
    /// Initialize TOTP enable for a user
    /// Returns QR code URL and secret for manual entry
    @Sendable func enableTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<TOTPEnableResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Check if MFA is already enabled
        if user.twoFactorEnabled {
            throw HTTPError(.badRequest, message: "MFA is already enabled")
        }
        
        // Generate new secret
        let secret = TOTPUtils.generateSecret()
        
        // Store secret temporarily (not enabled yet)
        user.twoFactorSecret = secret
        try await user.save(on: fluent.db())
        
        // Generate QR code URL using the proper method
        let qrCodeUrl = TOTPUtils.generateQRCodeURL(
            secret: secret,
            label: user.email,
            issuer: "EcommerceApp"
        )
        
        return .init(
            status: .ok,
            response: TOTPEnableResponse(
                secret: secret,
                qrCodeUrl: qrCodeUrl
            )
        )
    }
    
    /// Verify TOTP code during enrollment
    @Sendable func verifyTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Ensure email is verified before allowing MFA enable
        guard user.emailVerified else {
            throw HTTPError(.badRequest, message: "Email must be verified before enabling MFA")
        }
        
        // Decode verification request
        let verifyRequest = try await request.decode(as: TOTPVerifyRequest.self, context: context)
        
        // Ensure we have a secret to verify against
        guard let secret = user.twoFactorSecret else {
            throw HTTPError(.badRequest, message: "No MFA setup in progress")
        }
        
        // Verify the code
        if !TOTPUtils.verifyTOTPCode(code: verifyRequest.code, secret: secret) {
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Enable MFA and invalidate all tokens
        user.twoFactorEnabled = true
        user.tokenVersion += 1
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "TOTP code verified successfully",
                success: true
            )
        )
    }
    
    /// Activate TOTP after successful verification
    @Sendable func activateTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Verify the current code one last time
        let enableRequest = try await request.decode(as: TOTPVerifyRequest.self, context: context)
        
        guard let secret = user.twoFactorSecret else {
            throw HTTPError(.badRequest, message: "No MFA setup in progress")
        }
        
        if !TOTPUtils.verifyTOTPCode(code: enableRequest.code, secret: secret) {
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Enable MFA
        user.twoFactorEnabled = true
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Two-factor authentication enabled successfully",
                success: true
            )
        )
    }
    
    /// Disable TOTP
    @Sendable func disableTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Check if MFA is enabled
        guard user.twoFactorEnabled, user.twoFactorSecret != nil else {
            throw HTTPError(.badRequest, message: "MFA is not enabled")
        }
        
        // Get disable request with password
        let disableRequest: DisableTOTPRequest
        do {
            disableRequest = try await request.decode(as: DisableTOTPRequest.self, context: context)
        } catch {
            throw HTTPError(.badRequest, message: "Password verification required")
        }
        
        // Verify password
        guard let passwordHash = user.passwordHash else {
            throw HTTPError(.internalServerError, message: "Account configuration error. Please contact support.")
        }
        
        // Perform password verification
        let passwordValid = Bcrypt.verify(disableRequest.password, hash: passwordHash)
        
        if !passwordValid {
            throw HTTPError(.unauthorized, message: "Invalid password")
        }
        
        // Disable MFA
        user.twoFactorEnabled = false
        user.twoFactorSecret = nil
        user.tokenVersion += 1  // Increment token version to invalidate all existing tokens
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Multi-factor authentication has been disabled",
                success: true
            )
        )
    }
    
    /// Get current TOTP status
    @Sendable func getTOTPStatus(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<TOTPStatusResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        return .init(
            status: .ok,
            response: TOTPStatusResponse(
                enabled: user.twoFactorEnabled
            )
        )
    }
}

// MARK: - Request/Response Types

struct TOTPEnableResponse: Codable {
    let secret: String
    let qrCodeUrl: String
}

struct TOTPVerifyRequest: Codable {
    let code: String
}

struct DisableTOTPRequest: Codable {
    let password: String
}

struct TOTPStatusResponse: Codable {
    let enabled: Bool
}

extension TOTPEnableResponse: ResponseEncodable {}
extension TOTPStatusResponse: ResponseEncodable {} 
