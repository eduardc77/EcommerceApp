/// Request structure for TOTP verification
struct TOTPVerificationRequest: Codable {
    let stateToken: String
    let code: String

    enum CodingKeys: String, CodingKey {
        case stateToken = "state_token"
        case code
    }
}

struct TOTPSignInResponse: Codable {
    let stateToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case stateToken = "state_token"
        case expiresIn = "expires_in"
    }
}
