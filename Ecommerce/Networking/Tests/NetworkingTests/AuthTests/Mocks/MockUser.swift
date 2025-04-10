import Foundation
@testable import Networking

/// Provides mock user data for testing purposes
public extension UserResponse {
    static func mockUser() -> UserResponse {
        UserResponse(
            id: "user-123",
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            profilePicture: "https://example.com/avatar.png",
            role: .customer,
            emailVerified: true,
            createdAt: Date().ISO8601Format(),
            updatedAt: Date().ISO8601Format(),
            mfaEnabled: false,
            lastSignInAt: Date().ISO8601Format(),
            hasPasswordAuth: true
        )
    }
}
