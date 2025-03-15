import Foundation

/// Public user information encoded into HTTP response
public struct PublicUserResponse: Codable, Identifiable, Sendable {
    public let id: String  // UUID as string
    public let username: String
    public let displayName: String
    public let profilePicture: String?
    public let role: Role
    public let createdAt: String
    public let updatedAt: String

    public init(
        id: String,
        username: String,
        displayName: String,
        profilePicture: String?,
        role: Role,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.profilePicture = profilePicture
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Get creation date from ISO8601 string
    public var creationDate: Date? {
        ISO8601DateFormatter.date(from: createdAt)
    }
    
    /// Get last update date from ISO8601 string
    public var updateDate: Date? {
        ISO8601DateFormatter.date(from: updatedAt)
    }
} 
