@testable import App
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import Testing
import HTTPTypes

@Suite("Email MFA Tests")
struct EmailMFATests {
    @Test("Can enable and disable Email MFA")
    func testEmailMFAEnableDisable() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Create test user
            let requestBody = TestCreateUserRequest(
                username: "email_test_123",
                displayName: "Email Test User",
                email: "email_test_123@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
            }

            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)

            // Login to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "email_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                return authResponse
            }

            // Test email MFA setup endpoint
            try await client.execute(
                uri: "/api/v1/mfa/email/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
                #expect(messageResponse.message.contains("Verification code sent"))
            }

            // Test invalid email code
            try await client.execute(
                uri: "/api/v1/mfa/email/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "000000"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // Test valid email code
            try await client.execute(
                uri: "/api/v1/mfa/email/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
                #expect(messageResponse.message.contains("enabled successfully"))
            }

            // Sign in again after enabling email MFA
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "email_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                #expect(authResponse.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }

            // Send request for email verification (added this step)
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/send",
                method: .post,
                auth: .bearer(mfaSignInResponse.stateToken!)
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Complete email MFA verification - passing stateToken in the body
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(
                        stateToken: mfaSignInResponse.stateToken!,
                        code: "123456"
                    ),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }

            // Test email MFA disable with password in body
            try await client.execute(
                uri: "/api/v1/mfa/email/disable",
                method: .post,
                auth: .bearer(finalAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    DisableEmailMFARequest(password: "P@th3r#Bk9$mN"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
                #expect(messageResponse.message.contains("disabled successfully"))
            }
        }
    }

    @Test("Login flow with Email MFA works correctly")
    func testSignInWithEmailMFA() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Sign up and sign in user
            let requestBody = TestCreateUserRequest(
                username: "email_test_789",
                displayName: "Email Test User 3",
                email: "email_test_789@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
            }

            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)

            let initialAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "email_test_789", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                return authResponse
            }

            // Enable email MFA
            try await client.execute(
                uri: "/api/v1/mfa/email/enable",
                method: .post,
                auth: .bearer(initialAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Verify email MFA setup
            try await client.execute(
                uri: "/api/v1/mfa/email/verify",
                method: .post,
                auth: .bearer(initialAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Sign in again after enabling email MFA
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "email_test_789", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                #expect(authResponse.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Request email code (added this step)
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/send",
                method: .post,
                auth: .bearer(mfaSignInResponse.stateToken!)
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Complete email MFA verification - stateToken in body
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(stateToken: mfaSignInResponse.stateToken!, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }

            // Use the token to access protected endpoint
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(finalAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let responseBody = String(buffer: response.body)
                #expect(!responseBody.isEmpty)
            }
        }
    }

    @Test("Invalid Email MFA codes are rejected")
    func testInvalidEmailMFACodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "email_test_456",
                displayName: "Email Test User 4",
                email: "email_test_456@example.com",
                password: "P@th3r#Bk9$mN!Z",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
            }

            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)

            // Sign in
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "email_test_456", password: "P@th3r#Bk9$mN!Z")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                return authResponse
            }

            // Enable email MFA
            try await client.execute(
                uri: "/api/v1/mfa/email/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Verify email MFA setup
            try await client.execute(
                uri: "/api/v1/mfa/email/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Sign in
            let initialLoginResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "email_test_456", password: "P@th3r#Bk9$mN!Z")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                #expect(authResponse.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED)
                return authResponse
            }
            
            // Request email code (added this step)
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/send",
                method: .post,
                auth: .bearer(initialLoginResponse.stateToken!)
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }

            // Verify with invalid email code - stateToken in body
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(stateToken: initialLoginResponse.stateToken!, code: "000000"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // Verify with no email code
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: nil
            ) { response in
                #expect(response.status == .badRequest)
            }

            // Verify with valid email code - stateToken in body
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(stateToken: initialLoginResponse.stateToken!, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.tokenType == "Bearer")
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
            }
        }
    }
}
