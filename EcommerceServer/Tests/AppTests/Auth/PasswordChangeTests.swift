@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting

@Suite("Password Change Tests")
struct PasswordChangeTests {
    
    @Test("Password change requires authentication")
    func testPasswordChangeRequiresAuth() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Attempt to change password without authentication
            let requestBody = ChangePasswordRequest(
                currentPassword: "oldPassword123!",
                newPassword: "newPassword456!"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/password/change",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Password change validates current password")
    func testPasswordChangeValidatesCurrentPassword() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up and sign in user
            let signUpRequest = TestSignUpRequest(
                username: "password_user_123",
                displayName: "Password Test User",
                email: "passwordtest@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Complete email verification
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(signUpRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            try await client.completeEmailVerification(email: signUpRequest.email, stateToken: signUpResponse.stateToken!)

            // 2. Sign in to get token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest@example.com", password: "OldP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Try to change password with incorrect current password
            let invalidRequestBody = ChangePasswordRequest(
                currentPassword: "WrongP@ssw0rd",
                newPassword: "NewP@ssw0rd!9K"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/password/change",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(invalidRequestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Password change validates new password requirements")
    func testPasswordChangeValidatesNewPassword() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up and sign in user
            let signUpRequest = TestSignUpRequest(
                username: "password_user_456",
                displayName: "Password Test User 2",
                email: "passwordtest2@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Complete email verification
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(signUpRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            try await client.completeEmailVerification(email: signUpRequest.email, stateToken: signUpResponse.stateToken!)

            // 2. Sign in to get token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest2@example.com", password: "OldP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Try to change password with weak new password
            let weakPasswordRequest = ChangePasswordRequest(
                currentPassword: "OldP@ssw0rd!9K#",
                newPassword: "password"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/password/change",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(weakPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .badRequest)
            }
        }
    }
    
    @Test("Password change succeeds with valid inputs")
    func testPasswordChangeSucceeds() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up and sign in user
            let signUpRequest = TestSignUpRequest(
                username: "password_user_789",
                displayName: "Password Test User 3",
                email: "passwordtest3@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Complete email verification
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(signUpRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            try await client.completeEmailVerification(email: signUpRequest.email, stateToken: signUpResponse.stateToken!)

            // 2. Sign in to get token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest3@example.com", password: "OldP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Change password with valid inputs
            let validPasswordRequest = ChangePasswordRequest(
                currentPassword: "OldP@ssw0rd!9K#",
                newPassword: "NewP@ssw0rd!9K#"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/password/change",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(validPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)

                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success == true)
            }
            
            // 4. Verify old token is no longer valid
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // 5. Verify can sign in with new password
            let _ = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest3@example.com", password: "NewP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 6. Verify cannot sign in with old password
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest3@example.com", password: "OldP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Password change prevents reuse of old passwords")
    func testPasswordChangePreventsPreviouslyUsedPasswords() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up and sign in user
            let signUpRequest = TestSignUpRequest(
                username: "password_user_101",
                displayName: "Password Test User 4",
                email: "passwordtest4@example.com",
                password: "OldP@ssw0rd!9K#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            // Complete email verification
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(signUpRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            try await client.completeEmailVerification(email: signUpRequest.email, stateToken: signUpResponse.stateToken!)

            // 2. Sign in to get token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest4@example.com", password: "OldP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Change password to a new one
            let firstChangeRequest = ChangePasswordRequest(
                currentPassword: "OldP@ssw0rd!9K#",
                newPassword: "NewP@ssw0rd!9K#"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/password/change",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(firstChangeRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 4. Sign in with new password
            let newAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "passwordtest4@example.com", password: "NewP@ssw0rd!9K#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 5. Try to change back to the original password
            let revertChangeRequest = ChangePasswordRequest(
                currentPassword: "NewP@ssw0rd!9K#",
                newPassword: "OldP@ssw0rd!9K#"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/password/change",
                method: .post,
                auth: .bearer(newAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(revertChangeRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .badRequest)
                
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success == false)
                #expect(messageResponse.message.contains("previously used"))
            }
        }
    }
} 
