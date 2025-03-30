@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import HummingbirdOTP

@Suite("MFA Advanced Tests")
struct MFAAdvancedTests {

    @Test("Can select between multiple MFA methods")
    func testMFAMethodSelection() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Sign up test user with both Email and TOTP MFA enabled
            let requestBody = TestSignUpRequest(
                username: "multiple_mfa_test",
                displayName: "Multiple MFA Test User",
                email: "multiple_mfa@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)

            // Sign in to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "multiple_mfa_test", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // Enable Email MFA
            try await client.execute(
                uri: "/api/v1/mfa/email/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
            }

            // Verify Email MFA setup
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
            }

            // Sign in again to get a fresh token after enabling email MFA
            // (since token version was incremented when enabling email MFA)
            let freshAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "multiple_mfa_test", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED)
                return authResponse
            }

            // Complete email MFA verification to get a valid token
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/send",
                method: .post,
                auth: .bearer(freshAuthResponse.stateToken!)
            ) { response in
                #expect(response.status == .ok)
            }

            let emailVerifiedAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(stateToken: freshAuthResponse.stateToken!, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }

            // Enable TOTP
            let setupResponseData = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(emailVerifiedAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPEnableResponse.self, from: response.body)
            }

            // Verify TOTP setup
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(emailVerifiedAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }

            // Sign in again after enabling both MFA methods
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "multiple_mfa_test", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_REQUIRED)
                #expect(authResponse.availableMfaMethods != nil)
                #expect(authResponse.availableMfaMethods!.count == 2)
                #expect(authResponse.availableMfaMethods!.contains(.totp))
                #expect(authResponse.availableMfaMethods!.contains(.email))
                return authResponse
            }

            // Test MFA selection with invalid method
            try await client.execute(
                uri: "/api/v1/auth/mfa/select",
                method: .post,
                body: ByteBuffer(string: """
                    {
                        "stateToken": "\(mfaSignInResponse.stateToken!)",
                        "method": "invalid_method"
                    }
                    """)
            ) { response in
                #expect(response.status == .badRequest)
            }

            // Test MFA selection with TOTP method
            let totpSelectionResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/select",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    MFASelectionRequest(stateToken: mfaSignInResponse.stateToken!, method: .totp),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }

            // Complete TOTP verification after selection
            let totpCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: totpSelectionResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
            }

            // Sign in again to test email selection
            let secondSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "multiple_mfa_test", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_REQUIRED)
                return authResponse
            }

            // Test MFA selection with email method
            let emailSelectionResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/select",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    MFASelectionRequest(stateToken: secondSignInResponse.stateToken!, method: .email),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }

            // Request email code
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/send",
                method: .post,
                auth: .bearer(emailSelectionResponse.stateToken!)
            ) { response in
                #expect(response.status == .ok)
            }

            // Complete email verification
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(stateToken: emailSelectionResponse.stateToken!, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
            }
        }
    }

}
