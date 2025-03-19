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
    @Test("Can setup TOTP")
    func testTOTPSetup() async throws {
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
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // Login to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "totp_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Test TOTP setup endpoint
            let setupResponseData = try await client.execute(
                uri: "/api/v1/auth/totp/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let setupResponse = try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
                #expect(setupResponse.secret.isEmpty == false)
                #expect(setupResponse.qrCodeUrl.isEmpty == false)
                return setupResponse
            }
            
            // Test invalid TOTP code
            try await client.execute(
                uri: "/api/v1/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: "000100"), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Test valid TOTP code
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Test TOTP disable
            let disableCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/auth/totp/disable",
                method: .delete,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: disableCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }
    
    @Test("Can enable and disable TOTP")
    func testTOTPEnableDisable() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "totp_test_456",
                displayName: "TOTP Test User 2",
                email: "totp_test_456@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "totp_test_456", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Setup TOTP
            let setupResponse = try await client.execute(
                uri: "/api/v1/auth/totp/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }
            
            // Generate and use valid TOTP code to enable
            let code = try TOTP.generateTestCode(from: setupResponse.secret)
            let enableRequest = TOTPVerifyRequest(code: code)
            try await client.execute(
                uri: "/api/v1/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(enableRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }
            
            // Verify TOTP is enabled
            try await client.execute(
                uri: "/api/v1/auth/totp/status",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(TOTPStatusResponse.self, from: response.body)
                #expect(status.enabled)
            }
            
            // Generate new code for disabling
            let disableCode = try TOTP.generateTestCode(from: setupResponse.secret)
            let disableRequest = TOTPVerifyRequest(code: disableCode)
            try await client.execute(
                uri: "/api/v1/auth/totp/disable",
                method: .delete,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(disableRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }
            
            // Verify TOTP is disabled
            try await client.execute(
                uri: "/api/v1/auth/totp/status",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(TOTPStatusResponse.self, from: response.body)
                #expect(!status.enabled)
            }
        }
    }
    
    @Test("Login flow with TOTP works correctly")
    func testLoginWithTOTP() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "totp_test_789",
                displayName: "TOTP Test User 3",
                email: "totp_test_789@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "totp_test_789", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Setup and enable TOTP
            let setupResponse = try await client.execute(
                uri: "/api/v1/auth/totp/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }
            
            let enableCode = try TOTP.generateTestCode(from: setupResponse.secret)
            let enableRequest = TOTPVerifyRequest(code: enableCode)
            try await client.execute(
                uri: "/api/v1/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(enableRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Try login without TOTP code
            let initialLoginResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "totp_test_789", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .unauthorized)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.requiresTOTP)
                #expect(authResponse.accessToken.isEmpty)
                #expect(authResponse.tempToken != nil)
                return authResponse
            }
            
            // Login with invalid TOTP code
            try await client.execute(
                uri: "/api/v1/auth/login/verify-totp",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(tempToken: initialLoginResponse.tempToken!, code: "000100"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Login with valid TOTP code
            let loginCode = try TOTP.generateTestCode(from: setupResponse.secret)
            try await client.execute(
                uri: "/api/v1/auth/login/verify-totp",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(tempToken: initialLoginResponse.tempToken!, code: loginCode),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(!authResponse.requiresTOTP)
                #expect(!authResponse.accessToken.isEmpty)
                #expect(authResponse.tempToken == nil)
            }
        }
    }
    
    @Test("Invalid TOTP codes are rejected")
    func testInvalidTOTPCodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        let (secret, accessToken) = try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "totp_test_456",
                displayName: "TOTP Test User 4",
                email: "totp_test_456@example.com",
                password: "P@th3r#Bk9$mN!Z",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "totp_test_456", password: "P@th3r#Bk9$mN!Z")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Setup TOTP
            let setupResponse = try await client.execute(
                uri: "/api/v1/auth/totp/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }
            
            // Try to enable with invalid code
            let invalidRequest = TOTPVerifyRequest(code: "123456")
            try await client.execute(
                uri: "/api/v1/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(invalidRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Enable with valid code
            let validCode = try TOTP.generateTestCode(from: setupResponse.secret)
            let validRequest = TOTPVerifyRequest(code: validCode)
            try await client.execute(
                uri: "/api/v1/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            return (setupResponse.secret, authResponse.accessToken)
        }
        
        // Now test invalid TOTP codes in a separate test block
        try await app.test(.router) { client in
            // Try login with invalid TOTP code
            try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                headers: [HTTPField.Name("x-totp-code")!: "001000"],
                auth: .basic(username: "totp_test_456", password: "P@th3r#Bk9$mN!Z")
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Try to disable with invalid code
            let invalidRequest = TOTPVerifyRequest(code: "000100")
            try await client.execute(
                uri: "/api/v1/auth/totp/disable",
                method: .delete,
                auth: .bearer(accessToken),
                body: JSONEncoder().encodeAsByteBuffer(invalidRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Try with valid code to verify the secret still works
            let validCode = try TOTP.generateTestCode(from: secret)
            let validRequest = TOTPVerifyRequest(code: validCode)
            try await client.execute(
                uri: "/api/v1/auth/totp/disable",
                method: .delete,
                auth: .bearer(accessToken),
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }
} 
