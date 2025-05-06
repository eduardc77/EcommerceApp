import Foundation
@testable import Networking

actor MockAuthenticationService: AuthenticationServiceProtocol {
    // Test configuration
    private var signInResult: Result<AuthResponse, Error>?
    private var signUpResult: Result<AuthResponse, Error>?
    private var meResult: Result<UserResponse, Error>?
    
    // Call tracking
    private(set) var signInCalls: [(identifier: String, password: String)] = []
    private(set) var signUpCalls: [SignUpRequest] = []
    private(set) var meCalls: Int = 0
    private(set) var signOutCalls: Int = 0
    private(set) var verifyTOTPCalls: [(code: String, stateToken: String)] = []
    private(set) var verifyEmailMFACalls: [(code: String, stateToken: String)] = []
    private(set) var refreshTokenCalls: [String] = []
    
    // Test setup helpers
    func setSignInResult(_ result: Result<AuthResponse, Error>) {
        self.signInResult = result
    }
    
    func setSignUpResult(_ result: Result<AuthResponse, Error>) {
        self.signUpResult = result
    }
    
    func setMeResult(_ result: Result<UserResponse, Error>) {
        self.meResult = result
    }
    
    // Protocol implementation
    func signIn(request: SignInRequest) async throws -> AuthResponse {
        signInCalls.append((identifier: request.identifier, password: request.password))
        return try signInResult?.get() ?? createDefaultAuthResponse()
    }
    
    func signUp(request: SignUpRequest) async throws -> AuthResponse {
        signUpCalls.append(request)
        return try signUpResult?.get() ?? createDefaultAuthResponse()
    }
    
    func me() async throws -> UserResponse {
        meCalls += 1
        return try meResult?.get() ?? createDefaultUser()
    }
    
    func signOut() async throws {
        signOutCalls += 1
    }
    
    func verifyTOTPSignIn(code: String, stateToken: String) async throws -> AuthResponse {
        verifyTOTPCalls.append((code: code, stateToken: stateToken))
        return try signInResult?.get() ?? createDefaultAuthResponse()
    }
    
    func verifyEmailMFASignIn(code: String, stateToken: String) async throws -> AuthResponse {
        verifyEmailMFACalls.append((code: code, stateToken: stateToken))
        return try signInResult?.get() ?? createDefaultAuthResponse()
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        refreshTokenCalls.append(refreshToken)
        return createDefaultAuthResponse()
    }
    
    // Helper methods
    private func createDefaultAuthResponse() -> AuthResponse {
        AuthResponse(
            accessToken: "test-token",
            refreshToken: "test-refresh",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: "2024-01-01T01:00:00Z",
            user: createDefaultUser(),
            status: AuthResponse.STATUS_SUCCESS
        )
    }
    
    private func createDefaultUser() -> UserResponse {
        UserResponse(
            id: "test-id",
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            role: .customer,
            emailVerified: true,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            mfaEnabled: false,
            lastSignInAt: "2024-01-01T00:00:00Z",
            hasPasswordAuth: true
        )
    }
    
    // Default implementations returning success responses
    func selectMFAMethod(method: String, stateToken: String) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
    
    func getMFAMethods(stateToken: String?) async throws -> MFAMethodsResponse {
        MFAMethodsResponse()
    }
    
    func requestEmailCode(stateToken: String) async throws -> MessageResponse {
        MessageResponse(message: "Code sent", success: true)
    }
    
    func sendEmailMFASignIn(stateToken: String) async throws -> MessageResponse {
        MessageResponse(message: "Code sent", success: true)
    }
    
    func resendEmailMFASignIn(stateToken: String) async throws -> MessageResponse {
        MessageResponse(message: "Code resent", success: true)
    }
    
    func getUserInfo() async throws -> UserInfoResponse {
        UserInfoResponse(
            sub: "test-id",
            name: "Test User",
            email: "test@example.com",
            emailVerified: true,
            picture: nil,
            updatedAt: Int(Date().timeIntervalSince1970),
            role: "customer"
        )
    }
    
    func changePassword(request: ChangePasswordRequest) async throws {}
    
    func forgotPassword(email: String) async throws -> MessageResponse {
        MessageResponse(message: "Reset instructions sent", success: true)
    }
    
    func resetPassword(request: ResetPasswordRequest) async throws -> MessageResponse {
        MessageResponse(message: "Password reset", success: true)
    }
    
    func listSessions() async throws -> SessionListResponse {
        SessionListResponse(sessions: [], currentSessionId: nil)
    }
    
    func revokeSession(sessionId: String) async throws -> MessageResponse {
        MessageResponse(message: "Session revoked", success: true)
    }
    
    func revokeAllOtherSessions() async throws -> MessageResponse {
        MessageResponse(message: "Sessions revoked", success: true)
    }
    
    func cancelAuthentication() async throws -> MessageResponse {
        MessageResponse(message: "Authentication cancelled", success: true)
    }
    
    func revokeAccessToken(_ token: String) async throws -> MessageResponse {
        MessageResponse(message: "Token revoked", success: true)
    }
    
    func signInWithGoogle(idToken: String, accessToken: String?) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
    
    func handleGoogleCallback(code: String) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
    
    func signInWithApple(identityToken: String, authorizationCode: String, fullName: [String : String?]?, email: String?) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
    
    func handleAppleCallback(code: String) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
    
    func exchangeCodeForTokens(code: String, codeVerifier: String, redirectUri: String) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
    
    func resendInitialEmailVerificationCode(stateToken: String, email: String) async throws -> MessageResponse {
        MessageResponse(message: "Code resent", success: true)
    }
    
    func initiateSocialSignIn(provider: String, redirectUri: String, codeChallenge: String, codeChallengeMethod: String, state: String, scope: String?) async throws -> URL {
        URL(string: "https://example.com")!
    }
    
    func verifyRecoveryCode(code: String, stateToken: String) async throws -> AuthResponse {
        createDefaultAuthResponse()
    }
}
