public struct LoginRequest: Codable, Sendable {
    public let identifier: String
    public let password: String
    public let totpCode: String?
    public let emailCode: String?
    
    public init(identifier: String, password: String, totpCode: String? = nil, emailCode: String? = nil) {
        self.identifier = identifier
        self.password = password
        self.totpCode = totpCode
        self.emailCode = emailCode
    }
    
    // For backward compatibility with the backend
    private enum CodingKeys: String, CodingKey {
        case identifier = "email"  // Map identifier to email for the backend
        case password
        case totpCode
        case emailCode
    }
} 