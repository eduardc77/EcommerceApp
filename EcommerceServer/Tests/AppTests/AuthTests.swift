@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("Authentication Tests")
struct AuthTests {
    
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
    
    @Test("Can refresh access token")
    func testTokenRefresh() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "refreshuser",
                displayName: "Refresh Test User",
                email: "refresh@example.com",
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
            
            // 2. Login to get initial tokens
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "refresh@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Use refresh token to get new access token
            let refreshBody = RefreshTokenRequest(
                refreshToken: authResponse.refreshToken
            )
            let refreshResponse = try await client.execute(
                uri: "/api/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(refreshBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 4. Verify new access token works
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(refreshResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.email == "refresh@example.com")
            }
            
            // 5. Verify old access token is invalidated
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // 6. Verify old refresh token is invalidated
            let oldRefreshBody = RefreshTokenRequest(refreshToken: authResponse.refreshToken)
            try await client.execute(
                uri: "/api/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(oldRefreshBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Logout invalidates tokens")
    func testLogout() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "logoutuser",
                displayName: "Logout Test User",
                email: "logout@example.com",
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
            
            // 2. Login to get tokens
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "logout@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Logout
            try await client.execute(
                uri: "/api/auth/logout",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .noContent)
            }
            
            // 4. Verify access token is invalidated
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // 5. Verify refresh token is invalidated
            let refreshBody = RefreshTokenRequest(refreshToken: authResponse.refreshToken)
            try await client.execute(
                uri: "/api/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(refreshBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
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
    
    @Test("Blacklisted tokens are rejected")
    func testTokenBlacklisting() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create and login user
            let requestBody = TestCreateUserRequest(
                username: "blacklistuser",
                displayName: "Blacklist Test User",
                email: "blacklist@example.com",
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
            
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "blacklist@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 2. Use token successfully
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 3. Logout to blacklist token
            try await client.execute(
                uri: "/api/auth/logout",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .noContent)
            }
            
            // 4. Try to use blacklisted token
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Email update invalidates token")
    func testEmailUpdateTokenInvalidation() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "emailupdate",
                displayName: "Email Update User",
                email: "original@example.com",
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
            
            let authResponse = try await client.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "original@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 2. Update email - this should succeed but invalidate the token
            let updateRequest = UpdateUserRequest(
                displayName: nil,
                email: "updated@example.com",
                password: nil,
                avatar: nil,
                role: nil
            )
            try await client.execute(
                uri: "/api/users/me",
                method: .put,
                auth: .bearer(authResponse.accessToken),
                body: JSONEncoder().encodeAsByteBuffer(updateRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.email == "updated@example.com")
            }
            
            // 3. Token should be unauthorized for subsequent requests
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Should reject expired tokens")
    func testExpiredTokenRejection() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user first
            let requestBody = TestCreateUserRequest(
                username: "expireduser",
                displayName: "Expired Token User",
                email: "expired@example.com",
                password: "K9#mP2$vL5nQ8*x",
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
            
            // 2. Create JWT with immediate expiration
            let jwtConfig = JWTConfiguration.load()
            let jwtID = UUID().uuidString
            let issuedAt = Date()
            let expirationDate = Date(timeIntervalSinceNow: -1) // Expired 1 second ago
            
            let payload = JWTPayloadData(
                subject: .init(value: userResponse.id.uuidString),  // Use actual user ID
                expiration: .init(value: expirationDate),
                type: "access",
                issuer: jwtConfig.issuer,
                audience: jwtConfig.audience,
                issuedAt: issuedAt,
                id: jwtID,
                role: Role.customer.rawValue,
                tokenVersion: 0  // New users start with token version 0
            )
            
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
            
            // 3. Attempt to use expired token
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message == "Token has expired")
            }
        }
    }
    
    @Test("Should reject tokens with invalid signature")
    func testInvalidSignatureRejection() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user first
            let requestBody = TestCreateUserRequest(
                username: "signatureuser",
                displayName: "Invalid Signature User",
                email: "signature@example.com",
                password: "K9#mP2$vL5nQ8*x",
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
            
            // 2. Create JWT with different signing key
            let jwtConfig = JWTConfiguration.load()
            let jwtID = UUID().uuidString
            let issuedAt = Date()
            let expirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
            
            let payload = JWTPayloadData(
                subject: .init(value: userResponse.id.uuidString),  // Use actual user ID
                expiration: .init(value: expirationDate),
                type: "access",
                issuer: jwtConfig.issuer,
                audience: jwtConfig.audience,
                issuedAt: issuedAt,
                id: jwtID,
                role: Role.customer.rawValue,
                tokenVersion: 0
            )
            
            let signers = JWTKeyCollection()
            // Use a different secret key
            let differentSecret = "different-secret-key"
            guard let secretData = differentSecret.data(using: .utf8) else {
                throw HTTPError(.internalServerError, message: "JWT secret must be valid UTF-8")
            }
            
            await signers.add(
                hmac: HMACKey(key: SymmetricKey(data: secretData)),
                digestAlgorithm: .sha256,
                kid: "hb_local"
            )
            
            let token = try await signers.sign(payload, kid: "hb_local")
            
            // 3. Attempt to use token with invalid signature
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Should reject tokens with invalid claims")
    func testInvalidClaimsRejection() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create JWT with invalid issuer
            let jwtConfig = JWTConfiguration.load()
            let jwtID = UUID().uuidString
            let issuedAt = Date()
            let expirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
            
            let payload = JWTPayloadData(
                subject: .init(value: UUID().uuidString),  // Use random UUID since we're testing issuer claim
                expiration: .init(value: expirationDate),
                type: "access",
                issuer: "wrong.issuer",  // Invalid issuer
                audience: jwtConfig.audience,
                issuedAt: issuedAt,
                id: jwtID,
                role: Role.customer.rawValue,
                tokenVersion: 0
            )
            
            let signers = JWTKeyCollection()
            let jwtSecret = AppConfig.jwtSecret
            guard let secretData = jwtSecret.data(using: .utf8) else {
                throw HTTPError(.internalServerError, message: "JWT secret must be valid UTF-8")
            }
            
            await signers.add(
                hmac: HMACKey(key: SymmetricKey(data: secretData)),
                digestAlgorithm: .sha256,
                kid: "hb_local"
            )
            
            let token = try await signers.sign(payload, kid: "hb_local")
            
            // 2. Attempt to use token with invalid issuer
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
}
