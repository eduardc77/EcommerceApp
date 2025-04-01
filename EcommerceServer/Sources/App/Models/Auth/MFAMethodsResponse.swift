import Hummingbird

/// Response for available MFA methods
struct MFAMethodsResponse: Codable {
    /// Whether email-based MFA is enabled for the user
    let emailEnabled: Bool
    
    /// Whether TOTP-based MFA is enabled for the user
    let totpEnabled: Bool
    
    /// List of available MFA methods
    var availableMethods: [MFAMethod] {
        var methods: [MFAMethod] = []
        if totpEnabled { methods.append(.totp) }
        if emailEnabled { methods.append(.email) }
        return methods
    }

    enum CodingKeys: String, CodingKey {
        case emailEnabled = "email_enabled"
        case totpEnabled = "totp_enabled"
    }
}

extension MFAMethodsResponse: ResponseEncodable {}
