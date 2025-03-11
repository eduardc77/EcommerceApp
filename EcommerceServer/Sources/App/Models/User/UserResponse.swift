import Foundation
import Hummingbird

/// User encoded into HTTP response
struct UserResponse: ResponseCodable, Sendable {
    let id: String
    let username: String
    let displayName: String
    let email: String
    let avatar: String
    let role: Role
    let createdAt: String
    let updatedAt: String

    init(from user: User) {
        self.id = user.id?.uuidString ?? ""
        self.username = user.username
        self.displayName = user.displayName
        self.email = user.email
        self.avatar = user.avatar ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = user.role
        self.createdAt = user.createdAt?.ISO8601Format() ?? ""
        self.updatedAt = user.updatedAt?.ISO8601Format() ?? ""
    }
}

/// Public user information encoded into HTTP response
struct PublicUserResponse: ResponseCodable, Sendable {
    let username: String
    let displayName: String
    let role: String
    let createdAt: String
    let updatedAt: String

    init(from user: User) {
        self.username = user.username
        self.displayName = user.displayName
        self.role = user.role.rawValue
        self.createdAt = user.createdAt?.ISO8601Format() ?? ""
        self.updatedAt = user.updatedAt?.ISO8601Format() ?? ""
    }
} 
