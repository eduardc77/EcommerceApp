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
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                return authResponse
            }

            // 2. Request verification code
            try await client.execute(
                uri: "/api/v1/auth/verify-email/send",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    ResendVerificationRequest(email: requestBody.email),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
            }

            // 3. Complete email verification
            try await client.execute(
                uri: "/api/v1/auth/verify-email/confirm",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
            }

            // 4. Sign in after verification
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }

            // 5. Check verification status through user profile
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(userResponse.emailVerified == true)
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
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // 2. Try invalid code
            try await client.execute(
                uri: "/api/v1/auth/verify-email/confirm",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "000000"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .badRequest)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("No verification code found"))
            }
        }
    }

    @Test("Email verification with rate limiting")
    func testEmailVerificationRateLimiting() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Register user
            let requestBody = TestCreateUserRequest(
                username: "ratelimit",
                displayName: "Rate Limit Test",
                email: "ratelimit@example.com",
                password: "TestingV@lid143!#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )

            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // 2. Request verification code multiple times
            var rateLimitHit = false
            for _ in 1...6 {
                try await client.execute(
                    uri: "/api/v1/auth/verify-email/send",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(
                        ResendVerificationRequest(email: requestBody.email),
                        allocator: ByteBufferAllocator()
                    )
                ) { response in
                    if response.status == .tooManyRequests {
                        rateLimitHit = true
                        #expect(response.headers.contains(.retryAfter))
                        return
                    }
                    #expect(response.status == .ok)
                }
            }
            #expect(rateLimitHit)
        }
    }
}
