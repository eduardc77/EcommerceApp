/// Request for verifying an email MFA code during sign in
public struct EmailMFAVerificationRequest: Codable, Sendable {
    public let code: String
    public let stateToken: String
    
    public init(code: String, stateToken: String) {
        self.code = code
        self.stateToken = stateToken
    }
} 