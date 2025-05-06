import Foundation

/// Response for successful sign in containing JWT token and user info
public struct AuthResponse: Codable, Sendable {
    public let accessToken: String?  // Optional since it's not present during MFA/verification
    public let refreshToken: String?  // Optional since it's not present during MFA/verification
    public let tokenType: String
    public let expiresIn: UInt?  // Optional since it's not present during MFA/verification
    public let expiresAt: String?  // Optional since it's not present during MFA/verification
    public let user: UserResponse?  // Optional since it's not present during intermediate states
    public let stateToken: String?  // For multi-step auth flows
    public let status: String  // Clear state indication
    public let maskedEmail: String?  // For showing masked email in MFA/verification UI
    public let availableMfaMethods: [MFAMethod]?  // Available MFA methods for the user

    public init(
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
    
    /// Helper to get expiration date from ISO8601 string
    public var expirationDate: Date? {
        guard let expiresAt = expiresAt else { return nil }
        return ISO8601DateFormatter().date(from: expiresAt)
    }
}

/// Auth status constants
extension AuthResponse {
    // Base statuses
    public static let STATUS_SUCCESS = "SUCCESS"
    
    // Multi-factor authentication statuses
    public static let STATUS_MFA_REQUIRED = "MFA_REQUIRED"  // Generic MFA required
    public static let STATUS_MFA_TOTP_REQUIRED = "MFA_TOTP_REQUIRED"  // TOTP verification needed
    public static let STATUS_MFA_EMAIL_REQUIRED = "MFA_EMAIL_REQUIRED"  // Email verification needed
    public static let STATUS_MFA_RECOVERY_CODE_REQUIRED = "MFA_RECOVERY_CODE_REQUIRED"  // Recovery code verification needed
    
    // Account verification statuses
    public static let STATUS_VERIFICATION_REQUIRED = "VERIFICATION_REQUIRED"  // Generic verification needed
    public static let STATUS_EMAIL_VERIFICATION_REQUIRED = "EMAIL_VERIFICATION_REQUIRED"  // Email verification needed for new account
    
    // Password related statuses
    public static let STATUS_PASSWORD_RESET_REQUIRED = "PASSWORD_RESET_REQUIRED"  // Password reset needed
    public static let STATUS_PASSWORD_UPDATE_REQUIRED = "PASSWORD_UPDATE_REQUIRED"  // Password update needed (e.g., expired)
} 
