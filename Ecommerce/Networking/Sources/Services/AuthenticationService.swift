import OSLog

public protocol AuthenticationServiceProtocol {
    func login(dto: LoginRequest) async throws -> AuthResponse
    func register(dto: CreateUserRequest) async throws -> AuthResponse
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse
    func logout() async throws
    func me() async throws -> UserResponse
    func changePassword(current: String, new: String) async throws -> MessageResponse
    func requestEmailCode() async throws -> MessageResponse
    func forgotPassword(email: String) async throws -> MessageResponse
    func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse
}

public actor AuthenticationService: AuthenticationServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Networking", category: "AuthenticationService")

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }

    public func login(dto: LoginRequest) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.login(dto: dto),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("Login successful: \(response.user.displayName)")
        return response
    }

    public func register(dto: CreateUserRequest) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.register(dto: dto),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("Registration successful: \(response.user.displayName)")
        return response
    }

    public func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        let response: AuthResponse = try await apiClient.performRequest(
            from: Store.Authentication.refreshToken(refreshToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("Token refreshed successfully")
        return response
    }
    
    public func logout() async throws {
        let _: EmptyResponse = try await apiClient.performRequest(
            from: Store.Authentication.logout,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
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
    
    public func requestEmailCode() async throws -> MessageResponse {
        let response: MessageResponse = try await apiClient.performRequest(
            from: Store.Authentication.requestEmailCode,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
        logger.debug("Email code requested successfully")
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
}
