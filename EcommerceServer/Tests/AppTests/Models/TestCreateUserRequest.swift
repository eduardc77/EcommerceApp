import Foundation
@testable import App

// Shared request models for testing
struct TestCreateUserRequest: Encodable {
    let username: String
    let displayName: String
    let email: String
    let password: String
    let profilePicture: String?
    let role: Role?

    init(
        username: String,
        displayName: String,
        email: String,
        password: String,
        profilePicture: String? = "https://api.dicebear.com/7.x/avataaars/png",
        role: Role? = nil
    ) {
        self.username = username
        self.displayName = displayName
        self.email = email
        self.password = password
        self.profilePicture = profilePicture
        self.role = role
    }
}
