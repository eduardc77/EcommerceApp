@testable import Networking

actor MockUserService: UserServiceProtocol {
    // Test configuration
    private var updateProfileResult: Result<UserResponse, Error>?
    private var meResult: Result<UserResponse, Error>?
    
    // Call tracking
    private(set) var updateProfileCalls: [(id: String, request: UpdateUserRequest)] = []
    private(set) var meCalls: Int = 0
    
    // Test setup helpers
    func setUpdateProfileResult(_ result: Result<UserResponse, Error>) {
        self.updateProfileResult = result
    }
    
    func setMeResult(_ result: Result<UserResponse, Error>) {
        self.meResult = result
    }
    
    // Protocol implementation
    func updateProfile(id: String, dto: UpdateUserRequest) async throws -> UserResponse {
        updateProfileCalls.append((id: id, request: dto))
        return try updateProfileResult?.get() ?? createDefaultUser()
    }
    
    func me() async throws -> UserResponse {
        meCalls += 1
        return try meResult?.get() ?? createDefaultUser()
    }
    
    // Helper methods
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
    func getAllUsers() async throws -> [UserResponse] {
        [createDefaultUser()]
    }
    
    func getUser(id: String) async throws -> UserResponse {
        createDefaultUser()
    }
    
    func getUserPublic(id: String) async throws -> PublicUserResponse {
        PublicUserResponse(
            id: "test-id",
            username: "testuser",
            displayName: "Test User",
            profilePicture: nil,
            role: .customer,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z"
        )
    }
    
    func createUser(_ dto: AdminCreateUserRequest) async throws -> UserResponse {
        createDefaultUser()
    }
    
    func deleteUser(id: String) async throws -> MessageResponse {
        MessageResponse(message: "User deleted", success: true)
    }
    
    func checkAvailability(_ type: AvailabilityType) async throws -> AvailabilityResponse {
        AvailabilityResponse(
            available: true,
            identifier: "test@example.com",
            type: type.queryItem.key
        )
    }
    
    func getProfile() async throws -> UserResponse {
        createDefaultUser()
    }
    
    func updateRole(userId: String, request: UpdateRoleRequest) async throws -> UserResponse {
        createDefaultUser()
    }
}
