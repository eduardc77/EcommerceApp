public struct ResetPasswordRequest: Codable, Sendable {
    public let email: String
    public let code: String
    public let newPassword: String
    
    public init(email: String, code: String, newPassword: String) {
        self.email = email
        self.code = code
        self.newPassword = newPassword
    }
} 