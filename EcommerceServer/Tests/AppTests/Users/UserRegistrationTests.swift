@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("User Registration Tests")
struct UserRegistrationTests {
    @Test("Can create a new user")
    func testCreateUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            let requestBody = TestCreateUserRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // 1. Register user
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.user.username == "testuser")
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Verify can now login
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(!authResponse.accessToken.isEmpty)
            }
        }
    }
    
    @Test("Prevents duplicate email registration")
    func testDuplicateEmailRegistration() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let firstUser = TestCreateUserRequest(
                username: "firstuser",
                displayName: "First User",
                email: "duplicate@example.com",
                password: "TestingV@lid143!#Z",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(firstUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt to create second user with same email
            let secondUser = TestCreateUserRequest(
                username: "seconduser",
                displayName: "Second User",
                email: "duplicate@example.com",
                password: "TestingV@lid143!#Z",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(secondUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .conflict)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("already exists"))
            }
        }
    }
    
    @Test("Prevents duplicate username registration")
    func testDuplicateUsernameRegistration() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let firstUser = TestCreateUserRequest(
                username: "duplicateuser",
                displayName: "First User",
                email: "first@example.com",
                password: "TestingValid143!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(firstUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt to create second user with same username
            let secondUser = TestCreateUserRequest(
                username: "duplicateuser",
                displayName: "Second User",
                email: "second@example.com",
                password: "TestingValid143!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(secondUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .conflict)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("already exists"))
            }
        }
    }
} 
