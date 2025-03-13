import Foundation

/// Response for email verification status
public struct EmailVerificationStatusResponse: Codable, Sendable {
    public let enabled: Bool
    public let verified: Bool
    
    public init(enabled: Bool, verified: Bool) {
        self.enabled = enabled
        self.verified = verified
    }
} 