@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test("Can authenticate with locally created JWT")
    func testAuthenticateWithLocallyCreatedJWT() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "Testing132!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Login to get JWT
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "testuser", password: "Testing132!@#")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Access protected endpoint with JWT
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let responseBody = String(buffer: response.body)
                #expect(!responseBody.isEmpty)
            }
        }
    }
    
    @Test("Can authenticate with service created JWT")
    func testAuthenticateWithServiceCreatedJWT() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user first
            let requestBody = TestCreateUserRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "Testing132!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let userResponse = try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(UserResponse.self, from: response.body)
            }
            
            // 2. Create JWT with all required fields
            let jwtConfig = JWTConfiguration.load()
            let jwtID = UUID().uuidString
            let issuedAt = Date()
            let expirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
            
            let payload = JWTPayloadData(
                subject: .init(value: userResponse.id.uuidString),
                expiration: .init(value: expirationDate),
                type: "access",
                issuer: jwtConfig.issuer,
                audience: jwtConfig.audience,
                issuedAt: issuedAt,
                id: jwtID,
                role: Role.customer.rawValue,
                tokenVersion: 0  // New users start with token version 0
            )
            
            // Use the same secret and key ID as the application
            let signers = JWTKeyCollection()
            let jwtSecret = AppConfig.jwtSecret
            guard let secretData = jwtSecret.data(using: .utf8) else {
                throw HTTPError(.internalServerError, message: "JWT secret must be valid UTF-8")
            }
            
            await signers.add(
                hmac: HMACKey(key: SymmetricKey(data: secretData)),
                digestAlgorithm: .sha256,
                kid: "hb_local"  // Match the application's key ID
            )
            
            let token = try await signers.sign(payload, kid: "hb_local")
            
            // 3. Use the token to access protected endpoint
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .ok)
                let responseBody = String(buffer: response.body)
                #expect(!responseBody.isEmpty)
            }
        }
    }
    
    @Test("Invalid credentials return appropriate errors")
    func testInvalidCredentials() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Test non-existent user
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "nonexistent@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid credentials"))
            }
            
            // 2. Create user for wrong password test
            let requestBody = TestCreateUserRequest(
                username: "credentialuser",
                displayName: "Credential Test User",
                email: "credentials@example.com",
                password: "K9#mP2$vL5nQ8*x",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 3. Test wrong password
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "credentials@example.com", password: "wrongpassword")
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid credentials"))
            }
        }
    }
    
    @Test("Password validation rules are enforced")
    func testPasswordValidation() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Test too short password
            let shortPasswordRequest = TestCreateUserRequest(
                username: "testuser1",
                displayName: "Test User 1",
                email: "test1@example.com",
                password: "Short1!",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(shortPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                print("Response body: \(String(buffer: response.body))")
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password without uppercase
            let noUppercaseRequest = TestCreateUserRequest(
                username: "testuser2",
                displayName: "Test User 2",
                email: "test2@example.com",
                password: "nouppercase123!",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(noUppercaseRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test common password pattern
            let commonPasswordRequest = TestCreateUserRequest(
                username: "testuser3",
                displayName: "Test User 3",
                email: "test3@example.com",
                password: "Password123!",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(commonPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password with repeated characters
            let repeatedCharsRequest = TestCreateUserRequest(
                username: "testuser4",
                displayName: "Test User 4",
                email: "test4@example.com",
                password: "TestAAA123!!!",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(repeatedCharsRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password with sequential characters
            let sequentialRequest = TestCreateUserRequest(
                username: "testuser5",
                displayName: "Test User 5",
                email: "test5@example.com",
                password: "Test12345!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(sequentialRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password containing username
            let usernameInPasswordRequest = TestCreateUserRequest(
                username: "johndoe",
                displayName: "John Doe",
                email: "john@example.com",
                password: "johndoe123!@#A",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(usernameInPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test valid password
            let validRequest = TestCreateUserRequest(
                username: "validuser",
                displayName: "Valid User",
                email: "valid@example.com",
                password: "V3ryStr0ng&Unique!",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.username == "validuser")
            }
        }
    }
    
    @Test("Rate limiting prevents brute force")
    func testRateLimiting() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "ratelimituser",
                displayName: "Rate Limit Test User",
                email: "ratelimit@example.com",
                password: "K9#mP2$vL5nQ8*x",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt multiple rapid login requests
            for _ in 1...6 {
                try await client.execute(
                    uri: "/api/auth/login",
                    method: .post,
                    auth: .basic(username: "ratelimit@example.com", password: "wrongpassword")
                ) { response in
                    if response.status == .tooManyRequests {
                        // Rate limit hit
                        #expect(response.headers.contains(.retryAfter))
                        return
                    }
                    #expect(response.status == .unauthorized)
                }
            }
        }
    }
    
    @Test("Account lockout after failed attempts")
    func testAccountLockout() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "lockoutuser",
                displayName: "Lockout Test User",
                email: "lockout@example.com",
                password: "K9#mP2$vL5nQ8*x",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt multiple failed logins
            for _ in 1...4 {
                try await client.execute(
                    uri: "/api/auth/login",
                    method: .post,
                    auth: .basic(username: "lockout@example.com", password: "wrongpassword")
                ) { response in
                    #expect(response.status == .unauthorized)
                }
            }
            
            // 5th attempt should trigger lockout
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "lockout@example.com", password: "wrongpassword")
            ) { response in
                #expect(response.status == .tooManyRequests)
            }
            
            // Try correct password - should still be locked
            try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "lockout@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .tooManyRequests)
            }
        }
    }
} 