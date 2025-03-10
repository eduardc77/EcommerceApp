@testable import App
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import Testing
import HTTPTypes

@Suite("Email Verification Tests")
struct EmailVerificationTests {
    @Test("User can register and complete email verification")
    func testBasicEmailVerification() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Register new user
            let requestBody = TestCreateUserRequest(
                username: "verifytest",
                displayName: "Verify Test User",
                email: "verify@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )

            let _ = try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(UserResponse.self, from: response.body)
            }

            // 2. Complete email verification using the helper method
            try await client.completeEmailVerification(email: requestBody.email)

            // 3. Login after verification
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Check verification status
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.email == requestBody.email)
            }
        }
    }

    @Test("Email verification with 2FA setup")
    func testEmailVerification2FA() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Register and verify user
            let requestBody = TestCreateUserRequest(
                username: "email2fa",
                displayName: "Email 2FA User",
                email: "email2fa@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )

            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // 2. Complete initial email verification
            try await client.completeEmailVerification(email: requestBody.email)

            // 3. Login to get access token
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Enable 2FA with verification code
            try await client.execute(
                uri: "/api/auth/email/send-code",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
            }

            try await client.execute(
                uri: "/api/auth/email/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
            }

            // 5. Verify 2FA is required for login
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .unauthorized)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.requiresEmailVerification)
            }

            // 6. Complete login with 2FA code
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                headers: [HTTPField.Name("x-email-code")!: "123456"],
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(!authResponse.accessToken.isEmpty)
            }
        }
    }

    @Test("Invalid verification code handling")
    func testInvalidVerificationCode() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Register user
            let requestBody = TestCreateUserRequest(
                username: "invalidcode",
                displayName: "Invalid Code Test",
                email: "invalid@example.com",
                password: "TestingV@lid143!#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )

            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // 2. Request verification code
            try await client.execute(
                uri: "/api/auth/email/resend-verification",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    ResendVerificationRequest(email: requestBody.email),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
            }

            // 3. Try invalid code
            try await client.execute(
                uri: "/api/auth/email/verify-email",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(code: "000000"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
