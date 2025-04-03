/// Create user request object for admin user creation
public struct AdminCreateUserRequest: Codable, Sendable {
    public let username: String
    public let displayName: String
    public let email: String
    public let password: String
    public let profilePicture: String?
    public let role: Role
    
    public init(
        username: String,
        displayName: String,
        email: String,
        password: String,
        profilePicture: String? = "https://api.dicebear.com/7.x/avataaars/png",
        role: Role
    ) {
        self.username = username
        self.displayName = displayName
        self.email = email
        self.password = password
        self.profilePicture = profilePicture
        self.role = role
    }
}
