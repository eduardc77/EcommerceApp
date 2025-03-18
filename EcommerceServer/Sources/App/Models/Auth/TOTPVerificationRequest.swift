import Foundation

/// Request structure for TOTP verification
struct TOTPVerificationRequest: Codable {
    let tempToken: String
    let code: String
}

struct TOTPLoginResponse: Codable {
    let tempToken: String
    let expiresIn: Int
} 
