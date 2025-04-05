import Foundation

/// Response for available MFA methods
public struct MFAMethodsResponse: Codable, Sendable {
    /// Whether email-based MFA is enabled for the user
    public let emailMFAEnabled: Bool
    
    /// Whether TOTP-based MFA is enabled for the user
    public let totpMFAEnabled: Bool
    
    /// List of available MFA methods
    public var methods: [MFAMethod] {
        var methods: [MFAMethod] = []
        if totpMFAEnabled { methods.append(.totp) }
        if emailMFAEnabled { methods.append(.email) }
        return methods
    }
    
    public init(emailMFAEnabled: Bool = false, totpMFAEnabled: Bool = false) {
        self.emailMFAEnabled = emailMFAEnabled
        self.totpMFAEnabled = totpMFAEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case emailMFAEnabled = "email_mfa_enabled"
        case totpMFAEnabled = "totp_mfa_enabled"
    }
} 