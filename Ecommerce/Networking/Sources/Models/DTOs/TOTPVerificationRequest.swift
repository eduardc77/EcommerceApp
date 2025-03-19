import Foundation

/// Request for verifying a TOTP code during login
public struct TOTPVerificationRequest: Codable, Sendable {
    public let tempToken: String
    public let code: String
    
    public init(tempToken: String, code: String) {
        self.tempToken = tempToken
        self.code = code
    }
    
    private enum CodingKeys: String, CodingKey {
        case tempToken
        case code
    }
} 