import Foundation
import Hummingbird

/// User encoded into HTTP response
struct UserResponse: ResponseCodable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let email: String
    let profilePicture: String
    let role: Role
    let emailVerified: Bool
    let createdAt: String
    let updatedAt: String

    init(from user: User) {
        self.id = user.id?.uuidString ?? ""
        self.username = user.username
        self.displayName = user.displayName
        self.email = user.email
        self.profilePicture = user.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = user.role
        self.emailVerified = user.emailVerified
        self.createdAt = user.createdAt?.ISO8601Format() ?? ""
        self.updatedAt = user.updatedAt?.ISO8601Format() ?? ""
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
}
