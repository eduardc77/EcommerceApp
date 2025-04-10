import Foundation
import Testing
@testable import Networking

final class UserServiceTests {
    // MARK: - Test Properties
    let mockAPIClient: MockAPIClient
    var sut: UserService!
    
    // MARK: - Init
    init() {
        self.mockAPIClient = MockAPIClient()
    }
    
    // MARK: - Setup
    func setUp() async {
        sut = UserService(apiClient: mockAPIClient)
    }
    
    // MARK: - Get Users Tests
    @Test("Get all users returns array of users")
    func testGetAllUsersSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = [
            UserResponse.mockUser(),
            UserResponse(
                id: "user-456",
                username: "janedoe",
                displayName: "Jane Doe",
                email: "jane@example.com",
                profilePicture: "https://example.com/avatar2.png",
                role: .customer,
                emailVerified: true,
                createdAt: Date().ISO8601Format(),
                updatedAt: Date().ISO8601Format(),
                mfaEnabled: false,
                lastSignInAt: Date().ISO8601Format(),
                hasPasswordAuth: true
            )
        ]
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.getAll)
        
        // When
        let response = try await sut.getAllUsers()
        
        // Then
        #expect(response.count == 2)
        #expect(response[0].id == "user-123")
        #expect(response[1].id == "user-456")
    }
    
    @Test("Get user by ID returns user details")
    func testGetUserSuccess() async throws {
        await setUp()
        
        // Given
        let userId = "user-123"
        let expectedResponse = UserResponse.mockUser()
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.get(id: userId))
        
        // When
        let response = try await sut.getUser(id: userId)
        
        // Then
        #expect(response.id == userId)
        #expect(response.username == expectedResponse.username)
        #expect(response.email == expectedResponse.email)
        #expect(response.role == expectedResponse.role)
    }
    
    @Test("Get public user profile returns limited information")
    func testGetUserPublicSuccess() async throws {
        await setUp()
        
        // Given
        let userId = "user-123"
        let user = UserResponse.mockUser()
        let expectedResponse = user.asPublicUser
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.getPublic(id: userId))
        
        // When
        let response = try await sut.getUserPublic(id: userId)
        
        // Then
        #expect(response.id == userId)
        #expect(response.username == expectedResponse.username)
        #expect(response.displayName == expectedResponse.displayName)
        #expect(!response.createdAt.isEmpty)
    }
    
    // MARK: - Create User Tests
    @Test("Create user with admin request returns new user")
    func testCreateUserSuccess() async throws {
        await setUp()
        
        // Given
        let createRequest = AdminCreateUserRequest(
            username: "newuser",
            displayName: "New User",
            email: "new@example.com",
            password: "password123",
            role: .customer
        )
        let expectedResponse = UserResponse(
            id: "new-user-id",
            username: createRequest.username,
            displayName: createRequest.displayName,
            email: createRequest.email,
            profilePicture: createRequest.profilePicture,
            role: createRequest.role,
            emailVerified: false,
            createdAt: Date().ISO8601Format(),
            updatedAt: Date().ISO8601Format(),
            mfaEnabled: false,
            lastSignInAt: nil,
            hasPasswordAuth: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.create(dto: createRequest))
        
        // When
        let response = try await sut.createUser(createRequest)
        
        // Then
        #expect(response.username == createRequest.username)
        #expect(response.email == createRequest.email)
        #expect(response.role == createRequest.role)
        #expect(response.emailVerified == false)
    }
    
    // MARK: - Update Tests
    @Test("Update user profile returns updated user")
    func testUpdateProfileSuccess() async throws {
        await setUp()
        
        // Given
        let updateRequest = UpdateUserRequest(
            displayName: "Updated Name",
            email: "updated@example.com",
            profilePicture: "https://example.com/new-avatar.png"
        )
        let expectedResponse = UserResponse(
            id: "user-123",
            username: "testuser",
            displayName: updateRequest.displayName ?? "",
            email: updateRequest.email ?? "",
            profilePicture: updateRequest.profilePicture,
            role: .customer,
            emailVerified: true,
            createdAt: Date().ISO8601Format(),
            updatedAt: Date().ISO8601Format(),
            mfaEnabled: false,
            lastSignInAt: Date().ISO8601Format(),
            hasPasswordAuth: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.updateProfile(dto: updateRequest))
        
        // When
        let response = try await sut.updateProfile(id: "user-123", dto: updateRequest)
        
        // Then
        #expect(response.displayName == updateRequest.displayName)
        #expect(response.email == updateRequest.email)
        #expect(response.profilePicture == updateRequest.profilePicture)
    }
    
    @Test("Update user role returns updated user")
    func testUpdateRoleSuccess() async throws {
        await setUp()
        
        // Given
        let userId = "user-123"
        let updateRequest = UpdateRoleRequest(role: .admin)
        let expectedResponse = UserResponse(
            id: userId,
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            role: .admin,
            emailVerified: true,
            createdAt: Date().ISO8601Format(),
            updatedAt: Date().ISO8601Format(),
            mfaEnabled: false,
            lastSignInAt: Date().ISO8601Format(),
            hasPasswordAuth: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.updateRole(userId))
        
        // When
        let response = try await sut.updateRole(userId: userId, request: updateRequest)
        
        // Then
        #expect(response.role == .admin)
    }
    
    // MARK: - Delete Tests
    @Test("Delete user returns success message")
    func testDeleteUserSuccess() async throws {
        await setUp()
        
        // Given
        let userId = "user-123"
        let expectedResponse = MessageResponse(
            message: "User deleted successfully",
            success: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.delete(id: userId))
        
        // When
        let response = try await sut.deleteUser(id: userId)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
    
    // MARK: - Availability Tests
    @Test("Check username availability returns status")
    func testCheckUsernameAvailabilitySuccess() async throws {
        await setUp()
        
        // Given
        let type = AvailabilityType.username("newuser")
        let expectedResponse = AvailabilityResponse(
            available: true,
            identifier: "newuser",
            type: "username"
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.checkAvailability(type: type))
        
        // When
        let response = try await sut.checkAvailability(type)
        
        // Then
        #expect(response.available == true)
        #expect(response.identifier == "newuser")
        #expect(response.type == "username")
    }
    
    @Test("Check email availability returns status")
    func testCheckEmailAvailabilitySuccess() async throws {
        await setUp()
        
        // Given
        let type = AvailabilityType.email("new@example.com")
        let expectedResponse = AvailabilityResponse(
            available: true,
            identifier: "new@example.com",
            type: "email"
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.User.checkAvailability(type: type))
        
        // When
        let response = try await sut.checkAvailability(type)
        
        // Then
        #expect(response.available == true)
        #expect(response.identifier == "new@example.com")
        #expect(response.type == "email")
    }
    
    // MARK: - Profile Tests
    @Test("Get profile returns current user")
    func testGetProfileSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = UserResponse.mockUser()
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.me)
        
        // When
        let response = try await sut.getProfile()
        
        // Then
        #expect(response.id == expectedResponse.id)
        #expect(response.username == expectedResponse.username)
        #expect(response.email == expectedResponse.email)
        #expect(response.role == expectedResponse.role)
    }
} 