import Foundation

public struct UserResponse: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: String  // UUID as string
    public let username: String
    public let displayName: String
    public let email: String
    public let profilePicture: String?  // Optional since server might not have it
    public let role: Role
    public let createdAt: String
    public let updatedAt: String
    
    public init(
        id: String,
        username: String,
        displayName: String,
        email: String,
        profilePicture: String? = nil,
        role: Role,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
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

// MARK: - Conversions
extension UserResponse {
    /// Convert to public user response
    public var asPublicUser: PublicUserResponse {
        PublicUserResponse(
            id: id,
            username: username,
            displayName: displayName,
            profilePicture: profilePicture,
            role: role,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
} 
