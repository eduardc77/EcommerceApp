import Hummingbird

/// User encoded into HTTP response
struct UserResponse: ResponseCodable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let email: String
    let profilePicture: String
    let dateOfBirth: String?
    let gender: String?
    let role: Role
    let emailVerified: Bool
    let createdAt: String
    let updatedAt: String
    let hasPasswordAuth: Bool

    init(from user: User) {
        self.id = user.id?.uuidString ?? ""
        self.username = user.username
        self.displayName = user.displayName
        self.email = user.email
        self.profilePicture = user.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.dateOfBirth = user.dateOfBirth?.ISO8601Format()
        self.gender = user.gender
        self.role = user.role
        self.emailVerified = user.emailVerified
        self.createdAt = user.createdAt?.ISO8601Format() ?? ""
        self.updatedAt = user.updatedAt?.ISO8601Format() ?? ""
        self.hasPasswordAuth = user.passwordHash != nil
    }

    // Custom encoder to ensure null fields are included
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(username, forKey: .username)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(email, forKey: .email)
        try container.encode(profilePicture, forKey: .profilePicture)
        try container.encode(dateOfBirth, forKey: .dateOfBirth) // Will encode as null if nil
        try container.encode(gender, forKey: .gender) // Will encode as null if nil
        try container.encode(role, forKey: .role)
        try container.encode(emailVerified, forKey: .emailVerified)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(hasPasswordAuth, forKey: .hasPasswordAuth)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case email
        case profilePicture = "profile_picture"
        case dateOfBirth = "date_of_birth"
        case gender
        case role
        case emailVerified = "email_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case hasPasswordAuth = "has_password_auth"
    }
}

/// Public user information encoded into HTTP response
struct PublicUserResponse: ResponseCodable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let profilePicture: String
    let role: Role
    let createdAt: String
    let updatedAt: String

    init(from user: User) {
        self.id = user.id?.uuidString ?? ""
        self.username = user.username
        self.displayName = user.displayName
        self.profilePicture = user.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = user.role
        self.createdAt = user.createdAt?.ISO8601Format() ?? ""
        self.updatedAt = user.updatedAt?.ISO8601Format() ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case profilePicture = "profile_picture"
        case role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
