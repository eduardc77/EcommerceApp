import Foundation
import Networking

// MARK: - Auth Service
struct PreviewAuthenticationService: AuthenticationServiceProtocol {
    func login(dto: LoginRequest) async throws -> AuthResponse {
        AuthResponse(
            accessToken: "preview_access_token",
            refreshToken: "preview_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: .previewUser,
            requiresTOTP: false,
            requiresEmailVerification: false
        )
    }
    
    func register(dto: CreateUserRequest) async throws -> AuthResponse {
        AuthResponse(
            accessToken: "preview_access_token",
            refreshToken: "preview_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: .previewUser,
            requiresTOTP: false,
            requiresEmailVerification: true
        )
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        AuthResponse(
            accessToken: "preview_access_token",
            refreshToken: "preview_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: .previewUser,
            requiresTOTP: false,
            requiresEmailVerification: false
        )
    }

    func logout() async throws {}

    func me() async throws -> UserResponse {
        .previewUser
    }

    func changePassword(current: String, new: String) async throws -> MessageResponse {
        MessageResponse(message: "Password changed successfully", success: true)
    }

    func requestEmailCode() async throws -> MessageResponse {
        MessageResponse(message: "Email code sent", success: true)
    }

    func forgotPassword(email: String) async throws -> MessageResponse {
        MessageResponse(message: "Password reset email sent", success: true)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse {
        MessageResponse(message: "Password reset successfully", success: true)
    }
}

// MARK: - User Service
struct PreviewUserService: UserServiceProtocol {
    func getUserPublic(id: String) async throws -> Networking.PublicUserResponse {
        PublicUserResponse(
            id: id,
            username: "johndoe",
            displayName: "John Doe",
            avatar: "https://api.dicebear.com/7.x/avataaars/png",
            role: .customer,
            createdAt: "2025-02-23T21:51:49.000Z",
            updatedAt: "2025-02-23T21:51:49.000Z"
        )
    }

    func register(_ dto: Networking.CreateUserRequest) async throws -> Networking.UserResponse {
        .previewUser
    }

    func deleteUser(id: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "User deleted successfully", success: true)
    }

    func updateRole(userId: String, request: Networking.UpdateRoleRequest) async throws -> Networking.UserResponse {
        .previewUser
    }

    func getAllUsers() async throws -> [UserResponse] {
        [.previewUser]
    }
    
    func getUser(id: String) async throws -> UserResponse {
        .previewUser
    }
    
    func createUser(_ dto: CreateUserRequest) async throws -> UserResponse {
        .previewUser
    }
    
    func updateProfile(id: String, dto: UpdateUserRequest) async throws -> UserResponse {
        .previewUser
    }
    
    func checkAvailability(_ type: AvailabilityType) async throws -> AvailabilityResponse {
        switch type {
        case .username(let value):
            return AvailabilityResponse(available: true, identifier: value, type: "username")
        case .email(let value):
            return AvailabilityResponse(available: true, identifier: value, type: "email")
        }
    }

    func getProfile() async throws -> UserResponse {
        .previewUser
    }
}

// MARK: - Token Store
actor PreviewTokenStore: TokenStoreProtocol {
    func getToken() async throws -> OAuthToken? {
        Token(
            accessToken: "preview_access_token",
            refreshToken: "preview_refresh_token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        )
    }
    
    func setToken(_ token: OAuthToken) async throws {}
    func deleteToken() async {}
    func invalidateToken() async throws {}
}

// MARK: - Preview Data
extension UserResponse {
    static let previewUser = UserResponse(
        id: UUID().uuidString,
        username: "johndoe",
        displayName: "John Doe",
        email: "john@example.com",
        avatar: "https://api.dicebear.com/7.x/avataaars/png",
        role: .customer,
        createdAt: "2025-02-23T21:51:49.000Z",
        updatedAt: "2025-02-23T21:51:49.000Z"
    )
}

struct PreviewAPIClient: APIClient {

    func performRequest<T: Decodable & Sendable>(
        from endpoint: APIEndpoint,
        in environment: APIEnvironment,
        allowRetry: Bool = true,
        requiresAuthorization: Bool = true
    ) async throws -> T {
        // Return mock data based on the type
        switch T.self {
        case is [ProductResponse].Type:
            return [
                ProductResponse.previewProduct,
                .previewProduct2,
                .previewProduct3
            ] as! T
        case is [CategoryResponse].Type:
            return [
                CategoryResponse.previewCategory,
                .previewCategory2
            ] as! T
        case is ProductResponse.Type:
            return ProductResponse.previewProduct as! T
        case is CategoryResponse.Type:
            return CategoryResponse.previewCategory as! T
        case is UserResponse.Type:
            return UserResponse.previewUser as! T
        case is [UserResponse].Type:
            return [UserResponse.previewUser] as! T
        case is AuthResponse.Type:
            return AuthResponse(
                accessToken: "preview_access_token",
                refreshToken: "preview_refresh_token",
                tokenType: "Bearer",
                expiresIn: 3600,
                expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
                user: .previewUser,
                requiresTOTP: false,
                requiresEmailVerification: false
            ) as! T
        case is AvailabilityResponse.Type:
            return AvailabilityResponse(
                available: true,
                identifier: "test_user",
                type: "username"
            ) as! T
        default:
            fatalError("Unhandled preview type: \(T.self)")
        }
    }
}

// Add preview data
extension ProductResponse {
    static let previewProduct = ProductResponse(
        id: "1",
        title: "iPhone 15 Pro",
        description: "The latest iPhone with amazing features",
        price: 999,
        images: ["https://picsum.photos/400"],
        category: .previewCategory,
        seller: .previewUser,
        createdAt: "2025-02-23T21:51:49.000Z",
        updatedAt: "2025-02-23T21:51:49.000Z"
    )
    
    static let previewProduct2 = ProductResponse(
        id: "2",
        title: "MacBook Pro",
        description: "Powerful laptop for professionals",
        price: 1999,
        images: ["https://picsum.photos/401"],
        category: .previewCategory,
        seller: .previewUser,
        createdAt: "2025-02-23T21:51:49.000Z",
        updatedAt: "2025-02-23T21:51:49.000Z"
    )
    
    static let previewProduct3 = ProductResponse(
        id: "3",
        title: "iPad Pro",
        description: "The most versatile iPad yet",
        price: 799,
        images: ["https://picsum.photos/402"],
        category: .previewCategory2,
        seller: .previewUser,
        createdAt: "2025-02-23T21:51:49.000Z",
        updatedAt: "2025-02-23T21:51:49.000Z"
    )
}

extension CategoryResponse {
    static let previewCategory = CategoryResponse(
        id: "1",
        name: "Electronics",
        description: "Electronics category",
        image: "https://picsum.photos/200",
        createdAt: "2025-02-23T21:51:49.000Z",
        updatedAt: "2025-02-23T21:51:49.000Z",
        productCount: 3
    )
    
    static let previewCategory2 = CategoryResponse(
        id: "2",
        name: "Accessories",
        description: "Accessories category",
        image: "https://picsum.photos/201",
        createdAt: "2025-02-23T21:51:49.000Z",
        updatedAt: "2025-02-23T21:51:49.000Z",
        productCount: 1
    )
}

// MARK: - Email Verification Service
struct PreviewEmailVerificationService: EmailVerificationServiceProtocol {
    func getInitialStatus() async throws -> Networking.EmailVerificationStatusResponse {
        EmailVerificationStatusResponse(enabled: false, verified: true)
    }
    
    func get2FAStatus() async throws -> Networking.EmailVerificationStatusResponse {
        EmailVerificationStatusResponse(enabled: false, verified: true)
    }
    
    func setup2FA() async throws -> Networking.MessageResponse {
        MessageResponse(message: "Verification code sent", success: true)
    }
    
    func verify2FA(code: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "2FA enabled successfully", success: true)
    }
    
    func disable2FA() async throws -> Networking.MessageResponse {
        MessageResponse(message: "2FA disabled successfully", success: true)
    }
    
    func verifyInitialEmail(email: String, code: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "Initial email verified successfully", success: true)
    }
    
    func resendVerificationEmail(email: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "Verification email resent", success: true)
    }
}

// MARK: - TOTP Service
struct PreviewTOTPService: TOTPServiceProtocol {
    func setup() async throws -> Networking.TOTPSetupResponse {
        TOTPSetupResponse(
            secret: "ABCDEFGHIJKLMNOP",
            qrCodeUrl: "otpauth://totp/Preview:user@example.com?secret=ABCDEFGHIJKLMNOP&issuer=Preview"
        )
    }
    
    func verify(code: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "TOTP code verified", success: true)
    }
    
    func enable(code: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "TOTP enabled", success: true)
    }
    
    func disable(code: String) async throws -> Networking.MessageResponse {
        MessageResponse(message: "TOTP disabled", success: true)
    }
    
    func getStatus() async throws -> Networking.TOTPStatusResponse {
        TOTPStatusResponse(enabled: false)
    }
} 
