public protocol UserServiceProtocol {
    func getAllUsers() async throws -> [UserResponse]
    func getUser(id: String) async throws -> UserResponse
    func getUserPublic(id: String) async throws -> PublicUserResponse
    func createUser(_ dto: AdminCreateUserRequest) async throws -> UserResponse
    func updateProfile(id: String, dto: UpdateUserRequest) async throws -> UserResponse
    func deleteUser(id: String) async throws -> MessageResponse
    func checkAvailability(_ type: AvailabilityType) async throws -> AvailabilityResponse
    func getProfile() async throws -> UserResponse
    func updateRole(userId: String, request: UpdateRoleRequest) async throws -> UserResponse
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
            requiresAuthorization: true
        )
    }
    
    public func getUser(id: String) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.get(id: id),
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func getUserPublic(id: String) async throws -> PublicUserResponse {
        try await apiClient.performRequest(
            from: Store.User.getPublic(id: id),
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func createUser(_ dto: AdminCreateUserRequest) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.create(dto: dto),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func updateProfile(id: String, dto: UpdateUserRequest) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.updateProfile(dto: dto),
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func deleteUser(id: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.User.delete(id: id),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func checkAvailability(_ type: AvailabilityType) async throws -> AvailabilityResponse {
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
    
    public func updateRole(userId: String, request: UpdateRoleRequest) async throws -> UserResponse {
        try await apiClient.performRequest(
            from: Store.User.updateRole(userId),
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
} 
