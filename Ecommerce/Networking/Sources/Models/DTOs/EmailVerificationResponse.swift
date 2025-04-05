import Foundation

/// Response for email verification status
public struct EmailVerificationStatusResponse: Codable, Sendable {
    public let emailMfaEnabled: Bool
    public let emailVerified: Bool
    
    public init(emailMFAEnabled: Bool, emailVerified: Bool) {
        self.emailMfaEnabled = emailMFAEnabled
        self.emailVerified = emailVerified
    }
} 