import Foundation
@testable import App

// Shared request models for testing
struct TestCreateUserRequest: Encodable {
    let username: String
    let displayName: String
    let email: String
    let password: String
    let avatar: String?
    let role: Role?

    init(
        username: String,
        displayName: String,
        email: String,
        password: String,
        avatar: String? = "https://api.dicebear.com/7.x/avataaars/png",
        role: Role? = nil
    ) {
        self.username = username
        self.displayName = displayName
        self.email = email
        self.password = password
        self.avatar = avatar
        self.role = role
    }
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String
}

struct ChangePasswordRequest: Codable {
    let currentPassword: String
    let newPassword: String
}

// Shared response models for testing
struct ErrorResponse: Codable {
    struct ErrorDetail: Codable {
        let message: String
    }
    let error: ErrorDetail
}

struct TestAuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: UInt
    let expiresAt: String
    let user: TestUserResponse
    let requiresTOTP: Bool
    let requiresEmailVerification: Bool
}

struct TestUserResponse: Decodable {
    let id: String
    let username: String
    let displayName: String
    let email: String
    let avatar: String
    let role: Role
    let createdAt: String
    let updatedAt: String
}

struct TestPublicUserResponse: Decodable {
    let id: String
    let username: String
    let displayName: String
    let avatar: String?
    let role: Role
    let createdAt: String
    let updatedAt: String
}

struct TOTPSetupResponse: Codable {
    let secret: String
    let qrCodeUrl: String
}

struct TOTPStatusResponse: Codable {
    let enabled: Bool
}

struct TestEmailVerifyRequest: Codable {
    let code: String
} 

struct TestTOTPVerifyRequest: Codable {
    let code: String
}
