public struct SignInRequest: Codable, Sendable {
    /// The user's identifier - can be either email or username
    public let identifier: String
    /// The user's password
    public let password: String
    /// Optional custom token expiration time in seconds
    public let expiresIn: Int?
    
    public init(
        identifier: String, 
        password: String,
        expiresIn: Int? = nil
    ) {
        self.identifier = identifier
        self.password = password
        self.expiresIn = expiresIn
    }
} 
