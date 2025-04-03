/// Request for verifying a TOTP code during sign in
public struct TOTPVerificationRequest: Codable, Sendable {
    public let code: String
    
    public init(code: String) {
        self.code = code
    }
} 
