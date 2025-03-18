import Foundation

/// Request for verifying a TOTP code
public struct TOTPVerificationRequest: Codable, Sendable {
    public let code: String
    
    public init(code: String) {
        self.code = code
    }
    
    private enum CodingKeys: String, CodingKey {
        case code = "totp_code"
    }
} 