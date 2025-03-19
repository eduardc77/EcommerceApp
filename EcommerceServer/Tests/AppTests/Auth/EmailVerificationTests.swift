@testable import App
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import Testing
import HTTPTypes

struct EmailLoginVerifyRequest: Codable {
    let tempToken: String
    let code: String
}

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
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            let _ = try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Complete email verification using the helper method
            try await client.completeEmailVerification(email: requestBody.email)

            // 3. Login after verification
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Check verification status
            try await client.execute(
                uri: "/api/v1/auth/email/2fa/status",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(EmailVerificationStatusResponse.self, from: response.body)
                #expect(status.verified)
                #expect(!status.enabled)
            }
        }
    }

    @Test("Email verification with 2FA setup")
    func testEmailVerification2FA() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Register new user
            let requestBody = TestCreateUserRequest(
                username: "email2fa",
                displayName: "Email 2FA User",
                email: "email2fa@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // 2. Complete initial email verification
            try await client.completeEmailVerification(email: requestBody.email)

            // 3. Login to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Setup 2FA - this generates and sends the initial setup code
            try await client.execute(
                uri: "/api/v1/auth/email/2fa/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
            }

            // 5. Verify and enable 2FA with the setup code
            try await client.execute(
                uri: "/api/v1/auth/email/2fa/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(EmailVerifyRequest(code: "123456"), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }

            // 6. Try login - this should trigger automatic 2FA code sending
            let initialLoginResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .unauthorized)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.requiresEmailVerification)
                #expect(authResponse.tempToken != nil)
                return authResponse
            }

            // 7. Try login with invalid 2FA code
            try await client.execute(
                uri: "/api/v1/auth/login/verify-email",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailLoginVerifyRequest(tempToken: initialLoginResponse.tempToken!, code: "000000"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // 8. Try login with correct 2FA code (using test environment code)
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/auth/login/verify-email",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailLoginVerifyRequest(tempToken: initialLoginResponse.tempToken!, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(!authResponse.requiresEmailVerification)
                #expect(authResponse.accessToken != "")
                #expect(authResponse.refreshToken != "")
                return authResponse
            }

            // 9. Verify we can access protected routes with the new token
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(finalAuthResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
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
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // 2. Request verification code
            try await client.execute(
                uri: "/api/v1/auth/email/resend",
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
                uri: "/api/v1/auth/email/verify-initial",
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
