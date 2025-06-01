import Foundation

public struct UserResponse: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: String  // UUID as string
    public let username: String
    public let displayName: String
    public let email: String
    public let profilePicture: String?  // Optional since server might not have it
    public let dateOfBirth: String?
    public let gender: String?
    public let role: Role
    public let emailVerified: Bool
    public let createdAt: String?
    public let updatedAt: String?
    public let mfaEnabled: Bool? // Made optional to handle missing key in response
    public let lastSignInAt: String?
    public let hasPasswordAuth: Bool // Whether the user has password authentication
    
    public init(
        id: String,
        username: String,
        displayName: String,
        email: String,
        profilePicture: String? = nil,
        dateOfBirth: String? = nil,
        gender: String? = nil,
        role: Role,
        emailVerified: Bool,
        createdAt: String?,
        updatedAt: String?,
        mfaEnabled: Bool?,
        lastSignInAt: String?,
        hasPasswordAuth: Bool
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profilePicture = profilePicture
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.role = role
        self.emailVerified = emailVerified
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.mfaEnabled = mfaEnabled
        self.lastSignInAt = lastSignInAt
        self.hasPasswordAuth = hasPasswordAuth
    }
    
    /// Get creation date from ISO8601 string
    public var creationDate: Date? {
        ISO8601DateFormatter.date(from: createdAt ?? "")
    }
    
    /// Get last update date from ISO8601 string
    public var updateDate: Date? {
        ISO8601DateFormatter.date(from: updatedAt ?? "")
    }
    
    /// Get date of birth as Date object
    public var dateOfBirthDate: Date? {
        guard let dateOfBirth = dateOfBirth else { return nil }
        return ISO8601DateFormatter().date(from: dateOfBirth)
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
            createdAt: createdAt ?? "",
            updatedAt: updatedAt ?? ""
        )
    }
} 
