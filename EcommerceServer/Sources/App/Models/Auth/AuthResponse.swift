import Foundation
import Hummingbird

/// Response for successful sign in containing JWT token and user info
struct AuthResponse: Codable {
    let accessToken: String?  // Optional since it's not present during MFA/verification
    let refreshToken: String?  // Optional since it's not present during MFA/verification
    let tokenType: String
    let expiresIn: UInt?  // Optional since it's not present during MFA/verification
    let expiresAt: String?  // Optional since it's not present during MFA/verification
    let user: UserResponse?  // Optional since it's not present during intermediate states
    let stateToken: String?  // For multi-step auth flows
    let status: String  // Clear state indication
    let maskedEmail: String?  // For showing masked email in MFA/verification UI
    let availableMfaMethods: [MFAMethod]?  // Available MFA methods for the user
    
    init(
        accessToken: String? = nil,
        refreshToken: String? = nil,
        tokenType: String = "Bearer",
        expiresIn: UInt? = nil,
        expiresAt: String? = nil,
        user: UserResponse? = nil,
        stateToken: String? = nil,
        status: String,
        maskedEmail: String? = nil,
        availableMfaMethods: [MFAMethod]? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
        self.user = user
        self.stateToken = stateToken
        self.status = status
        self.maskedEmail = maskedEmail
        self.availableMfaMethods = availableMfaMethods
    }
}

/// Available MFA methods
enum MFAMethod: String, Codable {
    case totp = "totp"
    case email = "email"
}

/// Auth status constants
extension AuthResponse {
    // Base statuses
    static let STATUS_SUCCESS = "SUCCESS"
    
    // Multi-factor authentication statuses
    static let STATUS_MFA_REQUIRED = "MFA_REQUIRED"  // Generic MFA required
    static let STATUS_MFA_TOTP_REQUIRED = "MFA_TOTP_REQUIRED"  // TOTP verification needed
    static let STATUS_MFA_EMAIL_REQUIRED = "MFA_EMAIL_REQUIRED"  // Email verification needed
    
    // Account verification statuses
    static let STATUS_VERIFICATION_REQUIRED = "VERIFICATION_REQUIRED"  // Generic verification needed
    static let STATUS_EMAIL_VERIFICATION_REQUIRED = "EMAIL_VERIFICATION_REQUIRED"  // Email verification needed for new account
    
    // Password related statuses
    static let STATUS_PASSWORD_RESET_REQUIRED = "PASSWORD_RESET_REQUIRED"  // Password reset needed
    static let STATUS_PASSWORD_UPDATE_REQUIRED = "PASSWORD_UPDATE_REQUIRED"  // Password update needed (e.g., expired)
}

extension AuthResponse: ResponseEncodable {}

extension String {
    /// Masks an email address for display
    /// e.g. "john.doe@example.com" -> "j***@example.com"
    func maskEmail() -> String {
        let parts = self.split(separator: "@")
        guard parts.count == 2 else { return self }
        let username = String(parts[0])
        let domain = String(parts[1])
        let maskedUsername = username.prefix(1) + "***"
        return "\(maskedUsername)@\(domain)"
    }
}
