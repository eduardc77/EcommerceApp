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
                username: "totptest",
                displayName: "TOTP Test User",
                email: "totp@test.com",
                password: "P@th3r#Bk9$mN",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // Login to get access token
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "totptest", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Test TOTP setup endpoint
            let setupResponseData = try await client.execute(
                uri: "/api/auth/totp/setup",
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
                uri: "/api/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: "123456"), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Test valid TOTP code
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Test TOTP disable
            let disableCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/auth/totp/disable",
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
                username: "totptest2",
                displayName: "TOTP Test User 2",
                email: "totp2@test.com",
                password: "P@th3r#Bk9$mN",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "totptest2", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Setup TOTP
            let setupResponse = try await client.execute(
                uri: "/api/auth/totp/setup",
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
                uri: "/api/auth/totp/enable",
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
                uri: "/api/auth/totp/status",
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
                uri: "/api/auth/totp/disable",
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
                uri: "/api/auth/totp/status",
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
        let (secret, _) = try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "totptest3",
                displayName: "TOTP Test User 3",
                email: "totp3@test.com",
                password: "P@th3r#Bk9$mN",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "totptest3", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Setup and enable TOTP
            let setupResponse = try await client.execute(
                uri: "/api/auth/totp/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }
            
            let enableCode = try TOTP.generateTestCode(from: setupResponse.secret)
            let enableRequest = TOTPVerifyRequest(code: enableCode)
            try await client.execute(
                uri: "/api/auth/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(enableRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Try login without TOTP code
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "totptest3", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .unauthorized)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.requiresTOTP)
                #expect(authResponse.accessToken.isEmpty)
            }
            
            return (setupResponse.secret, authResponse.accessToken)
        }
        
        // Now test login with TOTP in a separate test block
        try await app.test(.router) { client in
            let loginCode = try TOTP.generateTestCode(from: secret)
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                headers: [HTTPField.Name("x-totp-code")!: loginCode],
                auth: .basic(username: "totptest3", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(!authResponse.requiresTOTP)
                #expect(!authResponse.accessToken.isEmpty)
            }
        }
    }
    
    @Test("Invalid TOTP codes are rejected")
    func testInvalidTOTPCodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        let (secret, accessToken) = try await app.test(.router) { client in
            // Create and login user
            let requestBody = TestCreateUserRequest(
                username: "totptest4",
                displayName: "TOTP Test User 4",
                email: "totp4@test.com",
                password: "P@th3r#Bk9$mN",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "totptest4", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Setup TOTP
            let setupResponse = try await client.execute(
                uri: "/api/auth/totp/setup",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPSetupResponse.self, from: response.body)
            }
            
            // Try to enable with invalid code
            let invalidRequest = TOTPVerifyRequest(code: "123456")
            try await client.execute(
                uri: "/api/auth/totp/enable",
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
                uri: "/api/auth/totp/enable",
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
                uri: "/api/auth/login",
                method: .post,
                headers: [HTTPField.Name("x-totp-code")!: "000000"],
                auth: .basic(username: "totptest4", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // Try to disable with invalid code
            let invalidRequest = TOTPVerifyRequest(code: "000000")
            try await client.execute(
                uri: "/api/auth/totp/disable",
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
                uri: "/api/auth/totp/disable",
                method: .delete,
                auth: .bearer(accessToken),
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }
} 
