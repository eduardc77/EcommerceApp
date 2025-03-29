@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import CryptoKit
import JWTKit

@Suite("Authentication Tests")
struct AuthenticationTests {
    @Test("Can authenticate with locally created JWT")
    func testAuthenticateWithLocallyCreatedJWT() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "test_user_123",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "Testing132!@#",
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
            
            // 2. Sign in to get JWT
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "test_user_123", password: "Testing132!@#")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 3. Access protected endpoint with JWT
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
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
                username: "test_user_123",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "Testing132!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let signUpResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(signUpResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // Sign in to get user ID
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.username, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 2. Create JWT with all required fields
            let jwtConfig = JWTConfiguration.load()
            let jwtID = UUID().uuidString
            let issuedAt = Date()
            let expirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
            
            let payload = JWTPayloadData(
                subject: .init(value: authResponse.user!.id),
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
                kid: "hb_local"
            )
            let token = try await signers.sign(payload, kid: "hb_local")
            
            // 3. Access protected endpoint with manually created JWT
            try await client.execute(
                uri: "/api/v1/auth/me",
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
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "nonexistent@example.com", password: "K9#mP2$vL5nQ8*xZ@")
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid credentials"))
            }
            
            // 2. Create user for wrong password test
            let requestBody = TestCreateUserRequest(
                username: "credential_user_123",
                displayName: "Credential Test User",
                email: "credentials@example.com",
                password: "K9#mP2$vL5nQ8*xZ@",
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
            
            // 3. Test wrong password
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: "wrongpassword")
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid credentials"))
            }
        }
    }
    
    @Test("Rate limiting prevents brute force")
    func testRateLimiting() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "rate_limit_123",
                displayName: "Rate Limit Test User",
                email: "ratelimit@example.com",
                password: "K9#mP2$vL5nQ8*xZ@",
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
            
            // 2. Attempt multiple rapid sign in requests
            for _ in 1...6 {
                try await client.execute(
                    uri: "/api/v1/auth/sign-in",
                    method: .post,
                    auth: .basic(username: requestBody.email, password: "wrongpassword")
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
                username: "lockout_user_123",
                displayName: "Lockout Test User",
                email: "lockout@example.com",
                password: "K9#mP2$vL5nQ8*xZ@",
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
            
            // 2. Attempt multiple failed logins
            for _ in 1...4 {
                try await client.execute(
                    uri: "/api/v1/auth/sign-in",
                    method: .post,
                    auth: .basic(username: requestBody.email, password: "wrongpassword")
                ) { response in
                    #expect(response.status == .unauthorized)
                }
            }
            
            // 5th attempt should trigger lockout
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: "wrongpassword")
            ) { response in
                #expect(response.status == .tooManyRequests)
            }
            
            // Try correct password - should still be locked
            try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .tooManyRequests)
            }
        }
    }
} 
