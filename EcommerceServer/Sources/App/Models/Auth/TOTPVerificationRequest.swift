import Foundation

/// Request structure for TOTP verification
struct TOTPVerificationRequest: Codable {
    let stateToken: String
    let code: String
}

struct TOTPSignInResponse: Codable {
    let stateToken: String
    let expiresIn: Int
}
