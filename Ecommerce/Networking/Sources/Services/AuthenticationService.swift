import OSLog
import Foundation

// Using the protocol defined in AuthenticationServiceProtocol.swift instead of redefining it here
public actor AuthenticationService: AuthenticationServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    private let authorizationManager: AuthorizationManagerProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Networking", category: "AuthenticationService")

    public init(
        apiClient: APIClient,
        authorizationManager: AuthorizationManagerProtocol,
        environment: Store.Environment = .develop
    ) {
        self.apiClient = apiClient
        self.authorizationManager = authorizationManager
        self.environment = environment
    }

    public func login(request: LoginRequest) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.login(dto: request),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )

        if response.requiresEmailVerification {
            // Store temporary token for email verification
            let dateFormatter = ISO8601DateFormatter()
            let expirationDate = Date().addingTimeInterval(300) // 5 minutes
            let tempToken = Token(
                accessToken: response.tempToken ?? "",
                refreshToken: "",
                tokenType: "Bearer",
                expiresIn: 300, // 5 minutes
                expiresAt: dateFormatter.string(from: expirationDate)
            )
            await authorizationManager.storeToken(tempToken)
        } else if !response.requiresTOTP {
            // Only store permanent tokens if no verification is required
            let token = Token(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                tokenType: response.tokenType,
                expiresIn: response.expiresIn,
                expiresAt: response.expiresAt
            )
            await authorizationManager.storeToken(token)
        }

        logger.debug("Login successful: \(response.user.displayName)")
        return response
    }

    /// Login with Google OAuth credentials
    /// - Parameters:
    ///   - idToken: The ID token received from Google Sign-In
    ///   - accessToken: The access token received from Google Sign-In (optional)
    /// - Returns: Authentication response with tokens and user information
    public func loginWithGoogle(idToken: String, accessToken: String? = nil) async throws -> AuthResponse {
        let params: [String: Any] = [
            "idToken": idToken,
            "accessToken": accessToken as Any
        ]
        
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.socialLogin(provider: "google", params: params),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        
        // Store the tokens
        let token = Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            expiresAt: response.expiresAt
        )
        await authorizationManager.storeToken(token)
        
        logger.debug("Google login successful: \(response.user.displayName)")
        return response
    }
    
    /// Login with Apple Sign In credentials
    /// - Parameters:
    ///   - identityToken: The identity token string from Sign in with Apple
    ///   - authorizationCode: The authorization code from Sign in with Apple
    ///   - fullName: User's name components (optional, only provided on first login)
    ///   - email: User's email (optional, only provided on first login)
    /// - Returns: Authentication response with tokens and user information
    public func loginWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]? = nil,
        email: String? = nil
    ) async throws -> AuthResponse {
        var params: [String: Any] = [
            "identityToken": identityToken,
            "authorizationCode": authorizationCode
        ]
        
        // Add optional parameters if provided
        if let email = email {
            params["email"] = email
        }
        
        if let fullName = fullName {
            params["fullName"] = fullName
        }
        
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.socialLogin(provider: "apple", params: params),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        
        // Store the tokens
        let token = Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            expiresAt: response.expiresAt
        )
        await authorizationManager.storeToken(token)
        
        logger.debug("Apple login successful: \(response.user.displayName)")
        return response
    }

    public func verifyEmail2FALogin(code: String, tempToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.verifyEmail2FALogin(code: code, tempToken: tempToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )

        // Store the tokens after successful verification
        let token = Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            expiresAt: response.expiresAt
        )
        await authorizationManager.storeToken(token)

        logger.debug("Email verification successful: \(response.user.displayName)")
        return response
    }

    public func verifyTOTPLogin(code: String, tempToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.verifyTOTPLogin(code: code, tempToken: tempToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )

        // Only store permanent tokens if no email verification is required
        if !response.requiresEmailVerification {
            let token = Token(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                tokenType: response.tokenType,
                expiresIn: response.expiresIn,
                expiresAt: response.expiresAt
            )
            await authorizationManager.storeToken(token)
        }

        logger.debug("TOTP verification successful: \(response.user.displayName)")
        return response
    }

    public func register(request: CreateUserRequest) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.register(dto: request),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )

        // Store the token
        let token = Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            expiresAt: response.expiresAt
        )
        await authorizationManager.storeToken(token)

        logger.debug("Registration successful: \(response.user.displayName)")
        return response
    }

    public func logout() async throws {
        let _: EmptyResponse = try await apiClient.performRequest(
            from: Store.Authentication.logout,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )

        // Clear the token
        try await authorizationManager.invalidateToken()

        logger.debug("Logged out successfully")
    }

    public func me() async throws -> UserResponse {
        let response: UserResponse = try await apiClient.performRequest(
            from: Store.Authentication.me,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
        logger.debug("Retrieved user profile: \(response.displayName)")
        return response
    }

    public func changePassword(current: String, new: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.changePassword(current: current, new: new),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        logger.debug("Password changed successfully")
        return response
    }

    public func requestEmailCode(tempToken: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.requestEmailCode(tempToken: tempToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("2FA Email verification code requested")
        return response
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

    public func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.resetPassword(email: email, code: code, newPassword: newPassword),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("Password reset successfully")
        return response
    }

    public func refreshToken(_ token: String) async throws -> AuthResponse {
        // Implementation needed
        fatalError("Method not implemented")
    }
}
