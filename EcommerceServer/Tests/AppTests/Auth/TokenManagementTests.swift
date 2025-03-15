@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("Token Management Tests")
struct TokenManagementTests {
    @Test("Can refresh access token")
    func testRefreshToken() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "refreshuser",
                displayName: "Refresh Test User",
                email: "refresh@example.com",
                password: "K9#mP2$vL5nQ8*x",
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

            // 2. Login to get initial tokens
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "refresh@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 3. Use refresh token to get new access token
            let refreshResponse = try await client.execute(
                uri: "/api/v1/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(["refreshToken": authResponse.refreshToken], allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Verify new access token works
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(refreshResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.username == "refreshuser")
            }

            // 5. Verify old access token is invalidated
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // 6. Verify old refresh token is invalidated
            try await client.execute(
                uri: "/api/v1/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(["refreshToken": authResponse.refreshToken], allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Logout invalidates tokens")
    func testLogoutInvalidatesTokens() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "logoutuser",
                displayName: "Logout Test User",
                email: "logout@example.com",
                password: "K9#mP2$vL5nQ8*x",
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

            // 2. Login to get tokens
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/login",
                method: .post,
                auth: .basic(username: "logout@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 3. Logout
            try await client.execute(
                uri: "/api/v1/auth/logout",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .noContent)
            }

            // 4. Verify access token is invalidated
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // 5. Verify refresh token is invalidated
            try await client.execute(
                uri: "/api/v1/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(["refreshToken": authResponse.refreshToken], allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Blacklisted tokens are rejected")
    func testBlacklistedTokens() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create and login user
            let requestBody = TestCreateUserRequest(
                username: "blacklistuser",
                displayName: "Blacklist Test User",
                email: "blacklist@example.com",
                password: "K9#mP2$vL5nQ8*x",
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
                auth: .basic(username: "blacklist@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Use token successfully
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
            }

            // 3. Logout to blacklist token
            try await client.execute(
                uri: "/api/v1/auth/logout",
                method: .post,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .noContent)
            }

            // 4. Try to use blacklisted token
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Email update invalidates token")
    func testEmailUpdateInvalidatesToken() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "emailupdate",
                displayName: "Email Update User",
                email: "original@example.com",
                password: "K9#mP2$vL5nQ8*xZ@",
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
                auth: .basic(username: "original@example.com", password: "K9#mP2$vL5nQ8*xZ@")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Update email
            let updateRequest = UpdateUserRequest(
                displayName: nil,
                email: "updated@example.com",
                password: nil,
                profilePicture: nil,
                role: nil
            )
            try await client.execute(
                uri: "/api/v1/users/update-profile",
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
                uri: "/api/v1/auth/me",
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
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let userResponse = try await client.execute(
                uri: "/api/v1/auth/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)

            // 2. Create expired token
            let expirationDate = Date().addingTimeInterval(-30) // Expired 30 seconds ago
            let token = try await JWTKeyCollection.generateTestToken(
                subject: userResponse.user.id,
                expiration: expirationDate
            )

            // Add a delay to ensure token expiration is processed
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay

            // 3. Attempt to use expired token
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message == "Token has expired")
            }
        }
    }
    
    @Test("Should reject tokens with mismatched version")
    func testTokenVersionMismatch() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create and login user
            let requestBody = TestCreateUserRequest(
                username: "versionuser",
                displayName: "Version Test User",
                email: "version@example.com",
                password: "K9#mP2$vL5nQ8*x",
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
                auth: .basic(username: "version@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Create token with incorrect version
            let expirationDate = Date(timeIntervalSinceNow: JWTConfiguration.load().accessTokenExpiration)
            let token = try await JWTKeyCollection.generateTestToken(
                subject: authResponse.user.id,
                expiration: expirationDate,
                tokenVersion: 999  // Invalid version
            )

            // 3. Try to use token with wrong version
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Token has been invalidated due to security changes"))
            }
        }
    }
}
