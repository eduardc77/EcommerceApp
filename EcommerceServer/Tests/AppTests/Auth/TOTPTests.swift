@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import HummingbirdOTP
import HTTPTypes
import JWTKit
import Testing

@Suite("TOTP Authentication Tests")
struct TOTPTests {
    @Test("Can enable and disable TOTP")
    func testTOTPEnableDisable() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Create test user
            let requestBody = TestCreateUserRequest(
                username: "totp_test_123",
                displayName: "TOTP Test User",
                email: "totp_test_123@example.com",
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

            // Login to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "totp_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // Test TOTP setup endpoint
            let setupResponseData = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let setupResponse = try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
                #expect(setupResponse.secret.isEmpty == false)
                #expect(setupResponse.qrCodeUrl.isEmpty == false)
                return setupResponse
            }

            // Test invalid TOTP code
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: "001000"), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // Test valid TOTP code
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }

            // Sign in again after enabling TOTP
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "totp_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                return authResponse
            }

            // Complete TOTP verification
            let totpCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: mfaSignInResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // Test TOTP disable with new token
            let disableCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/mfa/totp/disable",
                method: .post,
                auth: .bearer(finalAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: disableCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }

    @Test("Login flow with TOTP works correctly")
    func testSignInWithTOTP() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Sign up and sign in user
            let requestBody = TestCreateUserRequest(
                username: "totp_test_789",
                displayName: "TOTP Test User 3",
                email: "totp_test_789@example.com",
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

            let initialAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "totp_test_789", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // Enable TOTP
            let enableResponse = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(initialAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }

            let enableCode = try TOTP.generateTestCode(from: enableResponse.secret)
            let enableRequest = TOTPVerifyRequest(code: enableCode)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(initialAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(enableRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }

            // Sign in again after enabling TOTP
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "totp_test_789", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                return authResponse
            }

            // Complete TOTP verification
            let totpCode = try TOTP.generateTestCode(from: enableResponse.secret)
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: mfaSignInResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == "SUCCESS")
                #expect(!authResponse.accessToken!.isEmpty)
                return authResponse
            }

            // 3. Use the token to access protected endpoint
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

    @Test("Invalid TOTP codes are rejected")
    func testInvalidTOTPCodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "totp_test_456",
                displayName: "TOTP Test User 4",
                email: "totp_test_456@example.com",
                password: "P@th3r#Bk9$mN!Z",
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

            // Sign in
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "totp_test_456", password: "P@th3r#Bk9$mN!Z")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // Enable TOTP
            let setupResponse = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }

            let enableCode = try TOTP.generateTestCode(from: setupResponse.secret)
            let enableRequest = TOTPVerifyRequest(code: enableCode)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(enableRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }

            // Sign in
            let initialLoginResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "totp_test_456", password: "P@th3r#Bk9$mN!Z")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == "MFA_TOTP_REQUIRED")
                return authResponse
            }

            // Verify with invalid TOTP code
            try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: initialLoginResponse.stateToken!, code: "000100"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Verify with no TOTP code
            try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: nil
            ) { response in
                #expect(response.status == .badRequest)
            }
            
            // Verify with valid TOTP code
            let loginCode = try TOTP.generateTestCode(from: setupResponse.secret)

            try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: initialLoginResponse.stateToken!, code: loginCode),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == "SUCCESS")
                #expect(!authResponse.accessToken!.isEmpty)
            }
        }
    }
}
