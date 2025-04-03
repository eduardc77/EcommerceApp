import Foundation
import Networking

struct PreviewRefreshAPIClient: RefreshAPIClientProtocol {
    init() {}
    
    func refreshToken(_ refreshToken: String) async throws -> OAuthToken {
        // Return a mock token for preview
        Token(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))
        )
    }
}

// MARK: - Auth Service
struct PreviewAuthenticationService: AuthenticationServiceProtocol {
    
    private let authorizationManager: AuthorizationManagerProtocol
    
    init(authorizationManager: AuthorizationManagerProtocol = AuthorizationManager(
        refreshClient: PreviewRefreshAPIClient(),
        tokenStore: PreviewTokenStore()
    )) {
        self.authorizationManager = authorizationManager
    }
    
    func signIn(request: SignInRequest) async throws -> AuthResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func signUp(request: SignUpRequest) async throws -> AuthResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return AuthResponse(
            accessToken: nil,
            refreshToken: nil,
            tokenType: "Bearer",
            expiresIn: nil,
            expiresAt: nil,
            user: nil,
            stateToken: "preview-state-token",
            status: AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED,
            maskedEmail: request.email.maskEmail()
        )
    }
    
    func signOut() async throws {
        try await authorizationManager.invalidateToken()
    }
    
    func me() async throws -> UserResponse {
        .previewUser
    }
    
    func changePassword(request: ChangePasswordRequest) async throws {
        // Simulate successful password change
    }
    
    func requestEmailCode(stateToken: String) async throws -> MessageResponse {
        MessageResponse(message: "Email code sent successfully", success: true)
    }
    
    func forgotPassword(email: String) async throws -> MessageResponse {
        MessageResponse(message: "Password reset email sent", success: true)
    }
    
    func resetPassword(request: ResetPasswordRequest) async throws -> MessageResponse {
        MessageResponse(message: "Password reset successfully", success: true)
    }
    
    func signInWithGoogle(idToken: String, accessToken: String? = nil) async throws -> AuthResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]?,
        email: String?
    ) async throws -> AuthResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func getMFAMethods(stateToken: String?) async throws -> MFAMethodsResponse {
        MFAMethodsResponse(emailEnabled: true, totpEnabled: true)
    }
    
    func verifyTOTPSignIn(code: String, stateToken: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func verifyEmailMFASignIn(code: String, stateToken: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func verifyRecoveryCode(code: String, stateToken: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func selectMFAMethod(method: String, stateToken: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func sendEmailMFASignIn(stateToken: String) async throws -> MessageResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return MessageResponse(message: "Code sent", success: true)
    }
    
    func resendEmailMFASignIn(stateToken: String) async throws -> MessageResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return MessageResponse(message: "Code resent", success: true)
    }
    
    func getUserInfo() async throws -> UserInfoResponse {
        let id = UUID().uuidString
        return UserInfoResponse(
            sub: id,
            name: "John Appleseed",
            email: "john@example.com",
            emailVerified: true,
            picture: "https://api.dicebear.com/7.x/avataaars/png",
            updatedAt: Int(Date().timeIntervalSince1970),
            role: Role.customer.rawValue
        )
    }
    
    func handleGoogleCallback(code: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func handleAppleCallback(code: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectUri: String
    ) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func resendInitialEmailVerificationCode(stateToken: String, email: String) async throws -> MessageResponse {
        // Simulate network delay
        try await Task.sleep(for: .seconds(1))
        
        return MessageResponse(message: "Initial email verification Code resent", success: true)
    }
    
    func initiateSocialSignIn(
        provider: String,
        redirectUri: String,
        codeChallenge: String,
        codeChallengeMethod: String,
        state: String,
        scope: String?
    ) async throws -> URL {
        return URL(string: "https://example.com/oauth/authorize?provider=\(provider)&redirect_uri=\(redirectUri)&code_challenge=\(codeChallenge)&code_challenge_method=\(codeChallengeMethod)&state=\(state)\(scope.map { "&scope=\($0)" } ?? "")")!
    }
    
    func cancelAuthentication() async throws -> MessageResponse {
        return MessageResponse(message: "Authentication cancelled", success: true)
    }
    
    func revokeAccessToken(_ token: String) async throws -> MessageResponse {
        return MessageResponse(message: "Token revoked", success: true)
    }
    
    func revokeSession(sessionId: String) async throws -> MessageResponse {
        return MessageResponse(message: "Session revoked", success: true)
    }
    
    func revokeAllOtherSessions() async throws -> MessageResponse {
        return MessageResponse(message: "All other sessions revoked", success: true)
    }
    
    func listSessions() async throws -> SessionListResponse {
        return SessionListResponse(sessions: [], currentSessionId: "")
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
}

// MARK: - User Service
struct PreviewUserService: UserServiceProtocol {
    func getUserPublic(id: String) async throws -> PublicUserResponse {
        PublicUserResponse(
            id: id,
            username: "john_appleseed",
            displayName: "John Appleseed",
            profilePicture: "https://api.dicebear.com/7.x/avataaars/png",
            role: .customer,
            createdAt: "2025-02-23T21:51:49.000Z",
            updatedAt: "2025-02-23T21:51:49.000Z"
        )
    }
    
    func deleteUser(id: String) async throws -> MessageResponse {
        MessageResponse(message: "User deleted successfully", success: true)
    }
    
    func updateRole(userId: String, request: UpdateRoleRequest) async throws -> UserResponse {
        .previewUser
    }
    
    func getAllUsers() async throws -> [UserResponse] {
        [.previewUser]
    }
    
    func getUser(id: String) async throws -> UserResponse {
        .previewUser
    }
    
    func createUser(_ dto: AdminCreateUserRequest) async throws -> UserResponse {
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
    static var previewUser: UserResponse {
        let id = UUID().uuidString
        return UserResponse(
            id: id,
            username: "john_appleseed",
            displayName: "John Appleseed",
            email: "john@example.com",
            profilePicture: "https://api.dicebear.com/7.x/avataaars/png",
            role: .customer,
            emailVerified: true,
            createdAt: "2025-02-23T21:51:49.000Z",
            updatedAt: "2025-02-23T21:51:49.000Z",
            mfaEnabled: false,
            lastSignInAt: "2025-02-23T21:51:49.000Z"
        )
    }
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
                status: AuthResponse.STATUS_SUCCESS
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
    
    func getInitialStatus() async throws -> EmailVerificationStatusResponse {
        EmailVerificationStatusResponse(enabled: false, verified: true)
    }
    
    func getEmailMFAStatus() async throws -> EmailVerificationStatusResponse {
        EmailVerificationStatusResponse(enabled: false, verified: true)
    }
    
    func sendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        MessageResponse(message: "Verification code sent", success: true)
    }
    
    func resendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        MessageResponse(message: "Verification email resent", success: true)
    }
    
    func verifyInitialEmail(code: String, stateToken: String, email: String) async throws -> AuthResponse {
        return AuthResponse(
            accessToken: "preview-access-token",
            refreshToken: "preview-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.previewUser,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    func enableEmailMFA() async throws -> MessageResponse {
        MessageResponse(message: "Email MFA enabled successfully", success: true)
    }
    
    func verifyEmailMFA(code: String, email: String) async throws -> MessageResponse {
        MessageResponse(message: "Email MFA verified successfully", success: true)
    }
    
    func disableEmailMFA(password: String) async throws -> MessageResponse {
        MessageResponse(message: "Email MFA disabled successfully", success: true)
    }
    
    func resendEmailMFACode() async throws -> MessageResponse {
        MessageResponse(message: "Verification code resent", success: true)
    }
    
    func getEmailVerificationStatus() async throws -> EmailVerificationStatusResponse {
        EmailVerificationStatusResponse(enabled: false, verified: true)
    }
}

// MARK: - TOTP Service
struct PreviewTOTPService: TOTPServiceProtocol {
    
    func enableTOTP() async throws -> TOTPSetupResponse {
        TOTPSetupResponse(
            secret: "ABCDEFGHIJKLMNOP",
            qrCodeUrl: "otpauth://totp/Preview:user@example.com?secret=ABCDEFGHIJKLMNOP&issuer=Preview"
        )
    }
    
    func verifyTOTP(code: String) async throws -> MessageResponse {
        MessageResponse(message: "TOTP MFA enabled successfully", success: true)
    }
    
    func disableTOTP(password: String) async throws -> MessageResponse {
        MessageResponse(message: "TOTP MFA enabled successfully", success: true)
    }
    
    func getTOTPStatus() async throws -> TOTPStatusResponse {
        TOTPStatusResponse(enabled: true)
    }
}
