@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting

@Suite("Sign Up Tests")
struct SignUpTests {
    @Test("Can sign up a new user")
    func testSignUpUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            let requestBody = TestSignUpRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // 1. Sign up user
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Verify can now sign in
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(!authResponse.accessToken!.isEmpty)
                #expect(authResponse.user!.username == "testuser")
            }
        }
    }
    
    @Test("Prevents duplicate email registration")
    func testDuplicateEmailRegistration() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up first user
            let firstUser = TestSignUpRequest(
                username: "firstuser",
                displayName: "First User",
                email: "duplicate@example.com",
                password: "TestingV@lid143!#Z",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(firstUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt to sign up second user with same email
            let secondUser = TestSignUpRequest(
                username: "seconduser",
                displayName: "Second User",
                email: "duplicate@example.com",
                password: "TestingV@lid143!#Z",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
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
            // 1. Sign up first user
            let firstUser = TestSignUpRequest(
                username: "duplicateuser",
                displayName: "First User",
                email: "first@example.com",
                password: "TestingValid143!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(firstUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt to sign up second user with same username
            let secondUser = TestSignUpRequest(
                username: "duplicateuser",
                displayName: "Second User",
                email: "second@example.com",
                password: "TestingValid143!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
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
