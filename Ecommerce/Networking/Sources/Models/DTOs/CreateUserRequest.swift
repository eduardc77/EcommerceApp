public struct CreateUserRequest: Codable, Sendable {
    public let username: String
    public let displayName: String
    public let email: String
    public let password: String
    public let avatar: String
    public let role: Role?
    
    public init(
        username: String,
        displayName: String,
        email: String,
        password: String,
        avatar: String = "https://api.dicebear.com/7.x/avataaars/png",
        role: Role? = nil
    ) {
        self.username = username
        self.displayName = displayName
        self.email = email
        self.password = password
        self.avatar = avatar
        self.role = role
    }
} 