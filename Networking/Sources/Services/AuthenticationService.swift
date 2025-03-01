import OSLog

public protocol AuthenticationServiceProtocol {
    func login(dto: LoginRequest) async throws -> AuthResponse
    func register(dto: CreateUserRequest) async throws -> AuthResponse
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse
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
        let userResponse: UserResponse = try await apiClient.performRequest(
            from: Store.User.register(dto: dto),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("User registered successfully: \(userResponse.displayName)")
        
        let loginDTO = LoginRequest(identifier: dto.username, password: dto.password)
        return try await login(dto: loginDTO)
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
}
