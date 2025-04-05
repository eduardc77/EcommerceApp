import Hummingbird

/// Response for available MFA methods
struct MFAMethodsResponse: Codable {
    /// Whether email-based MFA is enabled for the user
    let emailMFAEnabled: Bool
    
    /// Whether TOTP-based MFA is enabled for the user
    let totpMFAEnabled: Bool
    
    /// List of available MFA methods
    var availableMethods: [MFAMethod] {
        var methods: [MFAMethod] = []
        if totpMFAEnabled { methods.append(.totp) }
        if emailMFAEnabled { methods.append(.email) }
        return methods
    }

    enum CodingKeys: String, CodingKey {
        case emailMFAEnabled = "email_mfa_enabled"
        case totpMFAEnabled = "totp_mfa_enabled"
    }
}

extension MFAMethodsResponse: ResponseEncodable {}
