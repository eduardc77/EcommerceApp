public protocol UserServiceProtocol {
    func getAllUsers() async throws -> [UserResponse]
    func getUser(id: String) async throws -> UserResponse
    func createUser(_ dto: CreateUserRequest) async throws -> UserResponse
    func updateUser(id: String, dto: UpdateUserRequest) async throws -> UserResponse
    func checkAvailability(_ type: Store.AvailabilityType) async throws -> AvailabilityResponse
    func getProfile() async throws -> UserResponse
}

public actor UserService: UserServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func getAllUsers() async throws -> [UserResponse] {
        try await apiClient.performRequest(
            from: Store.User.getAll,
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func getUser(id: String) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.get(id: id),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func createUser(_ dto: CreateUserRequest) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.register(dto: dto),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func updateUser(id: String, dto: UpdateUserRequest) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.update(id: id, dto: dto),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func checkAvailability(_ type: Store.AvailabilityType) async throws -> AvailabilityResponse {
        try await apiClient.performRequest(
            from: Store.User.checkAvailability(type: type),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func getProfile() async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.Authentication.me,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
} 
