@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import HummingbirdFluent
import HTTPTypes

@Suite("User Operations Tests")
struct UserOperationsTests {
    @Test("Can get own user details")
    func testGetOwnUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Sign up a user
            let user = TestSignUpRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: user.email)
            
            // Sign in to get token and user ID
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user.email, password: user.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let userId = authResponse.user!.id
            
            // Get own user details
            try await client.execute(
                uri: "/api/v1/users/\(userId)",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: response.body)
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
            // 1. Sign up first user
            let user1 = TestSignUpRequest(
                username: "user1",
                displayName: "User One",
                email: "user1@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            // Sign up first user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user1, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification for first user
            try await client.completeEmailVerification(email: user1.email)

            // Sign in as first user to get ID
            let user1Auth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user1.email, password: user1.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let user1Id = user1Auth.user!.id
            
            // 2. Sign up second user
            let user2 = TestSignUpRequest(
                username: "user2",
                displayName: "User Two",
                email: "user2@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up second user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user2, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification for second user
            try await client.completeEmailVerification(email: user2.email)
            
            // Sign in as second user
            let user2Auth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user2.email, password: user2.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Try to get first user's details
            try await client.execute(
                uri: "/api/v1/users/\(user1Id)",
                method: .get,
                auth: .bearer(user2Auth.accessToken!)
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
            // Sign up a user
            let user = TestSignUpRequest(
                username: "deletetest",
                displayName: "Delete Test",
                email: "deletetest@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            // Sign up user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: user.email)
            
            // Sign in to get token and user ID
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user.email, password: user.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let userId = authResponse.user!.id
            
            // Delete own account
            try await client.execute(
                uri: "/api/v1/users/\(userId)",
                method: .delete,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .noContent)
            }
            
            // Verify cannot get user details anymore
            try await client.execute(
                uri: "/api/v1/users/\(userId)",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Cannot delete other user's account")
    func testCannotDeleteOtherUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up first user
            let user1 = TestSignUpRequest(
                username: "user1delete",
                displayName: "User One Delete",
                email: "user1delete@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            // Sign up first user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user1, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification for first user
            try await client.completeEmailVerification(email: user1.email)

            // Sign in as first user to get ID
            let user1Auth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user1.email, password: user1.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let user1Id = user1Auth.user!.id
            
            // 2. Sign up second user
            let user2 = TestSignUpRequest(
                username: "user2delete",
                displayName: "User Two Delete",
                email: "user2delete@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up second user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user2, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 3. Sign in as second user
            var user2Token: String = ""
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user2.email, password: user2.password)
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                user2Token = authResponse.accessToken!
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
            // Sign up first user
            let user1 = TestSignUpRequest(
                username: "user1public",
                displayName: "User One Public",
                email: "user1public@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up first user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user1, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification for first user
            try await client.completeEmailVerification(email: user1.email)
            
            // Sign in as first user to get ID
            let user1Auth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user1.email, password: user1.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let user1Id = user1Auth.user!.id
            
            // Sign up second user
            let user2 = TestSignUpRequest(
                username: "user2public",
                displayName: "User Two Public",
                email: "user2public@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up second user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(user2, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification for second user
            try await client.completeEmailVerification(email: user2.email)
            
            // Sign in as second user
            let user2Auth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: user2.email, password: user2.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Get first user's public details
            try await client.execute(
                uri: "/api/v1/users/\(user1Id)/public",
                method: .get,
                auth: .bearer(user2Auth.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(PublicUserResponse.self, from: response.body)
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
            let adminUser = TestSignUpRequest(
                username: "adminuser",
                displayName: "Admin User",
                email: "admin@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up admin
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(adminUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Set admin role directly in database
            try await client.setUserRole(app: app, email: adminUser.email, role: .admin)
            
            // 2. Sign up a regular user
            let regularUser = TestSignUpRequest(
                username: "regularuser",
                displayName: "Regular User",
                email: "regular@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Sign up regular user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(regularUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification for regular user
            try await client.completeEmailVerification(email: regularUser.email)
            
            // Sign in as regular user to get ID
            let regularUserAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: regularUser.email, password: regularUser.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            let regularUserId = regularUserAuth.user!.id
            
            // Sign in as admin
            let adminAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: adminUser.email, password: adminUser.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Get regular user's details as admin
            try await client.execute(
                uri: "/api/v1/users/\(regularUserId)",
                method: .get,
                auth: .bearer(adminAuth.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(userResponse.id == regularUserId)
                #expect(userResponse.username == regularUser.username)
                #expect(userResponse.email == regularUser.email)  // Admin can see email
                #expect(userResponse.displayName == regularUser.displayName)
                #expect(userResponse.profilePicture == regularUser.profilePicture)
            }
        }
    }
} 
