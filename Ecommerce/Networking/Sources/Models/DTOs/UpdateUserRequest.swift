import Foundation

public struct UpdateUserRequest: Codable, Sendable {
    public let displayName: String?
    public let email: String?
    public let password: String?
    public let profilePicture: String?
    public let dateOfBirth: Date?
    public let gender: String?
    public let role: Role?
    
    public init(
        displayName: String? = nil,
        email: String? = nil,
        password: String? = nil,
        profilePicture: String? = nil,
        dateOfBirth: Date? = nil,
        gender: String? = nil,
        role: Role? = nil
    ) {
        self.displayName = displayName
        self.email = email
        self.password = password
        self.profilePicture = profilePicture
        self.dateOfBirth = dateOfBirth
        self.gender = gender
        self.role = role
    }
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case email
        case password
        case profilePicture = "profile_picture"
        case dateOfBirth = "date_of_birth"
        case gender
        case role
    }
} 
