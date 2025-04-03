import OSLog
import Foundation

// Using the protocol defined in AuthenticationServiceProtocol.swift instead of redefining it here
public final class AuthenticationService: AuthenticationServiceProtocol {
    private let apiClient: APIClient
    private let authorizationManager: AuthorizationManagerProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Ecommerce", category: "AuthenticationService")
    private let environment: Store.Environment

    public init(
        apiClient: APIClient,
        authorizationManager: AuthorizationManagerProtocol,
        environment: Store.Environment = .develop
    ) {
        self.apiClient = apiClient
        self.authorizationManager = authorizationManager
        self.environment = environment
    }

    public func signIn(request: SignInRequest) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.signIn(request: request),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func signUp(request: SignUpRequest) async throws -> AuthResponse {
        return try await apiClient.performRequest(
            from: Store.Authentication.signUp(request: request),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }

    public func signOut() async throws {
        let _: EmptyResponse = try await apiClient.performRequest(
            from: Store.Authentication.signOut,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        try await authorizationManager.invalidateToken()
    }

    public func me() async throws -> UserResponse {
        let response: UserResponse = try await apiClient.performRequest(
            from: Store.Authentication.me,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        return response
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.refreshToken(refreshToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func changePassword(request: ChangePasswordRequest) async throws {
        let _: EmptyResponse = try await apiClient.performRequest(
            from: Store.Authentication.changePassword(request: request),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }

    public func forgotPassword(email: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.forgotPassword(email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("Password reset requested for email")
        return response
    }

    public func resetPassword(request: ResetPasswordRequest) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.resetPassword(request: request),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func verifyTOTPSignIn(code: String, stateToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.verifyTOTPSignIn(code: code, stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func verifyEmailMFASignIn(code: String, stateToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.verifyEmailMFASignIn(code: code, stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func resendEmailMFASignIn(stateToken: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.resendEmailMFASignIn(stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func verifyRecoveryCode(code: String, stateToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.RecoveryCodes.verifyRecoveryCode(code: code, stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func selectMFAMethod(method: String, stateToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.selectMFAMethod(method: method, stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func getMFAMethods(stateToken: String?) async throws -> MFAMethodsResponse {
        let response: MFAMethodsResponse = try await apiClient.performRequest(
            from: Store.Authentication.getMFAMethods(stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func requestEmailCode(stateToken: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.resendEmailMFASignIn(stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func cancelAuthentication() async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.cancelAuthentication,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        return response
    }

    public func revokeAccessToken(_ token: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.revokeAccessToken(token),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        return response
    }

    public func revokeSession(sessionId: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.revokeSession(sessionId: sessionId),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        return response
    }

    public func revokeAllOtherSessions() async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.revokeAllOtherSessions,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        return response
    }

    public func listSessions() async throws -> SessionListResponse {
        let response: SessionListResponse = try await apiClient.performRequest(
            from: Store.Authentication.listSessions,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        return response
    }

    public func getUserInfo() async throws -> UserInfoResponse {
        let response: UserInfoResponse = try await apiClient.performRequest(
            from: Store.Authentication.getUserInfo,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
        return response
    }

    public func signInWithGoogle(idToken: String, accessToken: String? = nil) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.signInWithGoogle(idToken: idToken, accessToken: accessToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }
    
    public func handleGoogleCallback(code: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.handleOAuthCallback(code: code, state: ""),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }
    
    public func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]? = nil,
        email: String? = nil
    ) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.signInWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName,
                email: email
            ),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }
    
    public func handleAppleCallback(code: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.handleOAuthCallback(code: code, state: ""),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectUri: String
    ) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.exchangeCodeForTokens(
                code: code,
                codeVerifier: codeVerifier,
                redirectUri: redirectUri
            ),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        try await storeTokens(from: response)
        return response
    }

    public func initiateSocialSignIn(
        provider: String,
        redirectUri: String,
        codeChallenge: String,
        codeChallengeMethod: String,
        state: String,
        scope: String? = nil
    ) async throws -> URL {
        let response: URLResponse = try await apiClient.performRequest(
            from: Store.Authentication.socialSignIn(
                provider: provider,
                redirectUri: redirectUri,
                codeChallenge: codeChallenge,
                codeChallengeMethod: codeChallengeMethod,
                state: state,
                scope: scope
            ),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response.url
    }

    public func sendEmailMFASignIn(stateToken: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.sendEmailMFASignIn(stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func sendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.sendInitialVerificationEmail(stateToken: stateToken, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func resendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.resendInitialVerificationEmail(stateToken: stateToken, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    public func resendInitialEmailVerificationCode(stateToken: String, email: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.resendInitialVerificationEmail(stateToken: stateToken, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        return response
    }

    // MARK: - Private Helpers

    private func storeTokens(from response: AuthResponse) async throws {
        // Only store tokens for successful authentication
        // Skip token storage for verification states that don't have tokens
        if response.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED ||
           response.status == AuthResponse.STATUS_MFA_REQUIRED ||
           response.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED ||
           response.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED ||
           response.status == AuthResponse.STATUS_VERIFICATION_REQUIRED ||
           response.status == AuthResponse.STATUS_PASSWORD_RESET_REQUIRED ||
           response.status == AuthResponse.STATUS_PASSWORD_UPDATE_REQUIRED {
            return
        }
        
        // For successful authentication, ensure we have all required token fields
        guard let accessToken = response.accessToken,
              let refreshToken = response.refreshToken,
              let expiresIn = response.expiresIn,
              let expiresAt = response.expiresAt else {
            // Only throw if we're in a success state and missing token fields
            if response.status == AuthResponse.STATUS_SUCCESS {
                throw NetworkError.invalidResponse(description: "Missing required token fields")
            }
            return
        }
        
        let token = Token(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenType: response.tokenType,
            expiresIn: expiresIn,
            expiresAt: expiresAt
        )
        
        await authorizationManager.storeToken(token)
    }
}
