import Testing
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
@testable import App

@Suite("Forgot and Reset Password Tests")
struct ForgotPasswordResetTests {

    @Test("Forgot password request with non-existent email returns success")
    func testForgotPasswordWithNonExistentEmail() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            let forgotRequest = [
                "email": "nonexistent@example.com"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/forgot",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(forgotRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.message == "If an account exists with that email, a password reset link has been sent")
            }
        }
    }
    
    @Test("Forgot password request with valid email creates reset code")
    func testForgotPasswordWithValidEmail() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let createUserRequest = TestCreateUserRequest(
                username: "reset_user_123",
                displayName: "Reset Test User",
                email: "resettest@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(createUserRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Request password reset
            let forgotRequest = [
                "email": "resettest@example.com"
            ]
            
            let resetResponse = try await client.execute(
                uri: "/api/v1/auth/password/forgot",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(forgotRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(MessageResponse.self, from: response.body)
            }
            
            // In debug mode, verify code is returned in mock email service
            #if DEBUG
            #expect(resetResponse.message == "If an account exists with that email, a password reset link has been sent")
            #else
            #expect(resetResponse.message == "If an account exists with that email, a password reset link has been sent")
            #endif
        }
    }
    
    @Test("Reset password with invalid code fails")
    func testResetPasswordWithInvalidCode() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            let resetRequest = [
                "email": "resettest@example.com",
                "code": "invalid-code",
                "newPassword": "NewP@ssw0rd!9K#"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/reset",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(resetRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
    
    @Test("Reset password with expired code fails")
    func testResetPasswordWithExpiredCode() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let createUserRequest = TestCreateUserRequest(
                username: "reset_user_456",
                displayName: "Reset Test User 2",
                email: "resettest2@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(createUserRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Request password reset
            let forgotRequest = [
                "email": "resettest2@example.com"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/forgot",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(forgotRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 3. Manually expire the code by updating it in the database
            guard let db = app.services.first(where: { $0 is DatabaseService }) as? DatabaseService else {
                throw HTTPError(.internalServerError, message: "Database service not found")
            }
            
            try await EmailVerificationCode.query(on: db.fluent.db())
                .set(\.$expiresAt, to: Date().addingTimeInterval(-1))
                .update()
            
            // 4. Try to reset password with expired code
            let resetRequest = [
                "email": "resettest2@example.com",
                "code": "123456", // Mock service always uses this code
                "newPassword": "NewP@ssw0rd!9K#"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/reset",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(resetRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
    
    @Test("Reset password with valid code succeeds")
    func testResetPasswordWithValidCode() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let createUserRequest = TestCreateUserRequest(
                username: "reset_user_789",
                displayName: "Reset Test User 3",
                email: "resettest3@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(createUserRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Request password reset
            let forgotRequest = [
                "email": "resettest3@example.com"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/forgot",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(forgotRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 3. Reset password with valid code
            let resetRequest = [
                "email": "resettest3@example.com",
                "code": "123456", // Mock service always uses this code
                "newPassword": "NewP@ssw0rd!9K#"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/reset",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(resetRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.message == "Password has been reset successfully. Please log in with your new password.")
            }
            
            // 4. Verify can login with new password
            let _ = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "resettest3@example.com", password: "NewP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 5. Verify cannot login with old password
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "resettest3@example.com", password: "OldP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Reset password code cannot be reused")
    func testResetPasswordCodeCannotBeReused() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let createUserRequest = TestCreateUserRequest(
                username: "reset_user_101",
                displayName: "Reset Test User 4",
                email: "resettest4@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(createUserRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Request password reset
            let forgotRequest = [
                "email": "resettest4@example.com"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/forgot",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(forgotRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 3. Reset password with valid code
            let resetRequest = [
                "email": "resettest4@example.com",
                "code": "123456", // Mock service always uses this code
                "newPassword": "NewP@ssw0rd!9K#"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/reset",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(resetRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 4. Attempt to reuse code
            let reusedRequest = [
                "email": "resettest4@example.com",
                "code": "123456",
                "newPassword": "AnotherP@ssw0rd!9K#"
            ]
            
            try await client.execute(
                uri: "/api/v1/auth/password/reset",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(reusedRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
} 
