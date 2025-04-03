import Foundation

/// Response for available MFA methods
public struct MFAMethodsResponse: Codable, Sendable {
    /// Whether email-based MFA is enabled for the user
    public let emailEnabled: Bool
    
    /// Whether TOTP-based MFA is enabled for the user
    public let totpEnabled: Bool
    
    /// List of available MFA methods
    public var methods: [MFAMethod] {
        var methods: [MFAMethod] = []
        if totpEnabled { methods.append(.totp) }
        if emailEnabled { methods.append(.email) }
        return methods
    }
    
    public init(emailEnabled: Bool = false, totpEnabled: Bool = false) {
        self.emailEnabled = emailEnabled
        self.totpEnabled = totpEnabled
    }
    
    enum CodingKeys: String, CodingKey {
        case emailEnabled = "email_enabled"
        case totpEnabled = "totp_enabled"
    }
} 