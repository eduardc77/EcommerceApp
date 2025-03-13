/// Public user information encoded into HTTP response
public struct PublicUserResponse: Codable, Sendable {
    public let username: String
    public let displayName: String
    public let role: String
    public let createdAt: String
    public let updatedAt: String

    public init(
        username: String,
        displayName: String,
        role: String,
        createdAt: String,
        updatedAt: String
    ) {
        self.username = username
        self.displayName = displayName
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 