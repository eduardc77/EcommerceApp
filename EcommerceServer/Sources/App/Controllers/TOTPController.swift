import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdOTP
import FluentKit
import CryptoKit
import HummingbirdFluent

/// Controller for managing TOTP (Time-based One-Time Password) functionality
struct TOTPController {
    typealias Context = AppRequestContext
    let fluent: Fluent
    
    init(fluent: Fluent) {
        self.fluent = fluent
    }
    
    /// Add protected routes for TOTP management
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.post("setup", use: setupTOTP)
        group.post("verify", use: verifyTOTP)
        group.post("enable", use: enableTOTP)
        group.delete("disable", use: disableTOTP)
        group.get("status", use: getTOTPStatus)
    }
    
    /// Initialize TOTP setup for a user
    /// Returns QR code URL and secret for manual entry
    @Sendable func setupTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<TOTPSetupResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Check if 2FA is already enabled
        if user.twoFactorEnabled {
            throw HTTPError(.badRequest, message: "2FA is already enabled")
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
            issuer: "YourApp"
        )
        
        return .init(
            status: .ok,
            response: TOTPSetupResponse(
                secret: secret,
                qrCodeUrl: qrCodeUrl
            )
        )
    }
    
    /// Verify TOTP code during setup
    @Sendable func verifyTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Decode verification request
        let verifyRequest = try await request.decode(as: TOTPVerifyRequest.self, context: context)
        
        // Ensure we have a secret to verify against
        guard let secret = user.twoFactorSecret else {
            throw HTTPError(.badRequest, message: "No 2FA setup in progress")
        }
        
        // Verify the code
        if !TOTPUtils.verifyTOTPCode(code: verifyRequest.code, secret: secret) {
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Enable 2FA and invalidate all tokens
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
    
    /// Enable TOTP after successful verification
    @Sendable func enableTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Verify the current code one last time
        let enableRequest = try await request.decode(as: TOTPVerifyRequest.self, context: context)
        
        guard let secret = user.twoFactorSecret else {
            throw HTTPError(.badRequest, message: "No 2FA setup in progress")
        }
        
        if !TOTPUtils.verifyTOTPCode(code: enableRequest.code, secret: secret) {
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Enable 2FA
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
    
    /// Disable TOTP for a user
    @Sendable func disableTOTP(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        guard let user = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Verify current TOTP code before disabling
        let disableRequest = try await request.decode(as: TOTPVerifyRequest.self, context: context)
        
        guard let secret = user.twoFactorSecret else {
            throw HTTPError(.badRequest, message: "2FA is not enabled")
        }
        
        if !TOTPUtils.verifyTOTPCode(code: disableRequest.code, secret: secret) {
            throw HTTPError(.unauthorized, message: "Invalid verification code")
        }
        
        // Disable 2FA
        user.twoFactorEnabled = false
        user.twoFactorSecret = nil
        try await user.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "Two-factor authentication has been disabled",
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

struct TOTPSetupResponse: Codable {
    let secret: String
    let qrCodeUrl: String
}

struct TOTPVerifyRequest: Codable {
    let code: String
}

struct TOTPStatusResponse: Codable {
    let enabled: Bool
}

extension TOTPSetupResponse: ResponseEncodable {}
extension TOTPStatusResponse: ResponseEncodable {} 
