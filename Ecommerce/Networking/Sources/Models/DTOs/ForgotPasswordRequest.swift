public struct ForgotPasswordRequest: Codable, Sendable {
    public let email: String
    
    public init(email: String) {
        self.email = email
    }
} 