public struct LoginRequest: Codable, Sendable {
    public let identifier: String
    public let password: String
    
    public init(identifier: String, password: String) {
        self.identifier = identifier
        self.password = password
    }
    
    // For backward compatibility with the backend
    private enum CodingKeys: String, CodingKey {
        case identifier = "email"  // Map identifier to email for the backend
        case password
    }
} 