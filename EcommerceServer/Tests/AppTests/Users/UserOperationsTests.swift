@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import HummingbirdFluent
import JWTKit
import Testing
import HTTPTypes
import FluentKit

@Suite("User Operations Tests")
struct UserOperationsTests {
    @Test("Can get own user details")
    func testGetOwnUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create a user
            let user = TestCreateUserRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            var userId: String = ""
            
            // Register user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                userId = authResponse.user.id
            }
            
            // 2. Login to get token
            var accessToken: String = ""
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: user.email, password: user.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                accessToken = authResponse.accessToken
            }
            
            // 3. Get own user details
            try await client.execute(
                uri: "/api/v1/users/\(userId)",
                method: .get,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(accessToken)"]
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(TestUserResponse.self, from: response.body)
                #expect(userResponse.id == userId)
                #expect(userResponse.username == user.username)
                #expect(userResponse.email == user.email)
            }
        }
    }
    
    @Test("Cannot get other user's details")
    func testCannotGetOtherUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let user1 = TestCreateUserRequest(
                username: "user1",
                displayName: "User One",
                email: "user1@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            var user1Id: String = ""
            
            // Register first user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user1, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                user1Id = authResponse.user.id
            }
            
            // 2. Create second user
            let user2 = TestCreateUserRequest(
                username: "user2",
                displayName: "User Two",
                email: "user2@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register second user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user2, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 3. Login as second user
            var user2Token: String = ""
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: user2.email, password: user2.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                user2Token = authResponse.accessToken
            }
            
            // 4. Try to get first user's details
            try await client.execute(
                uri: "/api/v1/users/\(user1Id)",
                method: .get,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(user2Token)"]
            ) { response in
                #expect(response.status == .forbidden)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("don't have permission"))
            }
        }
    }
    
    @Test("Can delete own user account")
    func testDeleteOwnUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create a user
            let user = TestCreateUserRequest(
                username: "deletetest",
                displayName: "Delete Test",
                email: "deletetest@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            var userId: String = ""
            
            // Register user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                userId = authResponse.user.id
            }
            
            // 2. Login to get token
            var accessToken: String = ""
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: user.email, password: user.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                accessToken = authResponse.accessToken
            }
            
            // 3. Delete own account
            try await client.execute(
                uri: "/api/v1/users/\(userId)",
                method: .delete,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(accessToken)"]
            ) { response in
                #expect(response.status == .noContent)
            }
            
            // 4. Verify cannot get user details anymore
            try await client.execute(
                uri: "/api/v1/users/\(userId)",
                method: .get,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(accessToken)"]
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Cannot delete other user's account")
    func testCannotDeleteOtherUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let user1 = TestCreateUserRequest(
                username: "user1delete",
                displayName: "User One Delete",
                email: "user1delete@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            var user1Id: String = ""
            
            // Register first user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user1, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                user1Id = authResponse.user.id
            }
            
            // 2. Create second user
            let user2 = TestCreateUserRequest(
                username: "user2delete",
                displayName: "User Two Delete",
                email: "user2delete@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register second user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user2, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 3. Login as second user
            var user2Token: String = ""
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: user2.email, password: user2.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                user2Token = authResponse.accessToken
            }
            
            // 4. Try to delete first user's account
            try await client.execute(
                uri: "/api/v1/users/\(user1Id)",
                method: .delete,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(user2Token)"]
            ) { response in
                #expect(response.status == .forbidden)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("don't have permission"))
            }
        }
    }
    
    @Test("Can get other user's public details")
    func testCanGetOtherUserPublicDetails() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let user1 = TestCreateUserRequest(
                username: "user1public",
                displayName: "User One Public",
                email: "user1public@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            var user1Id: String = ""
            
            // Register first user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user1, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                user1Id = authResponse.user.id
            }
            
            // 2. Create second user
            let user2 = TestCreateUserRequest(
                username: "user2public",
                displayName: "User Two Public",
                email: "user2public@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register second user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user2, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 3. Login as second user
            var user2Token: String = ""
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: user2.email, password: user2.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                user2Token = authResponse.accessToken
            }
            
            // 4. Get first user's public details
            try await client.execute(
                uri: "/api/v1/users/\(user1Id)/public",
                method: .get,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(user2Token)"]
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(TestPublicUserResponse.self, from: response.body)
                #expect(userResponse.username == user1.username)
                #expect(userResponse.displayName == user1.displayName)
                #expect(userResponse.role == .customer)
                
                // Convert string dates to Date objects for comparison
                let dateFormatter = ISO8601DateFormatter()
                let createdAt = dateFormatter.date(from: userResponse.createdAt)!
                let updatedAt = dateFormatter.date(from: userResponse.updatedAt)!
                let oneMinuteAgo = Date().addingTimeInterval(-60)
                
                #expect(createdAt > oneMinuteAgo)  // Created within last minute
                #expect(updatedAt > oneMinuteAgo)  // Updated within last minute
                
                // Verify private fields are not included
                let mirror = Mirror(reflecting: userResponse)
                let properties = mirror.children.map { $0.label ?? "" }
                #expect(!properties.contains("email"))
            }
        }
    }
    
    @Test("Admin can get full user details")
    func testAdminCanGetFullUserDetails() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create an admin user
            let adminUser = TestCreateUserRequest(
                username: "adminuser",
                displayName: "Admin User",
                email: "admin@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Register admin
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(adminUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Set admin role directly in database
            try await client.setUserRole(app: app, email: adminUser.email, role: .admin)
            
            // 2. Create a regular user
            let regularUser = TestCreateUserRequest(
                username: "regularuser",
                displayName: "Regular User",
                email: "regular@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            var regularUserId: String = ""
            
            // Register regular user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(regularUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                regularUserId = authResponse.user.id
            }
            
            // 3. Login as admin
            var adminToken: String = ""
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: adminUser.email, password: adminUser.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(TestAuthResponse.self, from: response.body)
                adminToken = authResponse.accessToken
            }
            
            // 4. Get regular user's details as admin
            try await client.execute(
                uri: "/api/v1/users/\(regularUserId)",
                method: .get,
                headers: [HTTPField.Name("Authorization")!: "Bearer \(adminToken)"]
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(TestUserResponse.self, from: response.body)
                #expect(userResponse.id == regularUserId)
                #expect(userResponse.username == regularUser.username)
                #expect(userResponse.email == regularUser.email)  // Admin can see email
                #expect(userResponse.displayName == regularUser.displayName)
                #expect(userResponse.avatar == regularUser.avatar)
            }
        }
    }
} 
