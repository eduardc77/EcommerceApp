public struct UpdateUserRequest: Codable, Sendable {
    public let displayName: String?
    public let email: String?
    public let password: String?
    public let avatar: String?
    public let role: Role?
    
    public init(
        displayName: String? = nil,
        email: String? = nil,
        password: String? = nil,
        avatar: String? = nil,
        role: Role? = nil
    ) {
        self.displayName = displayName
        self.email = email
        self.password = password
        self.avatar = avatar
        self.role = role
    }
} 