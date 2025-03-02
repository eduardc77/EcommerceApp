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

    @Test("Should handle concurrent token refresh requests")
    func testConcurrentTokenRefresh() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { tester in
            // 1. Create and login user
            let requestBody = TestCreateUserRequest(
                username: "concurrentuser",
                displayName: "Concurrent Test User",
                email: "concurrent@example.com",
                password: "K9#mP2$vL5nQ8*x",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await tester.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }

            let authResponse = try await tester.execute(
                uri: "/api/auth/login",
                method: .post,
                auth: .basic(username: "concurrent@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Create refresh request body
            let refreshBody = RefreshTokenRequest(refreshToken: authResponse.refreshToken)
            let encodedBody = try JSONEncoder().encodeAsByteBuffer(refreshBody, allocator: ByteBufferAllocator())

            // 3. Send concurrent refresh requests with a small delay between them
            let results = try await withThrowingTaskGroup(of: (Int, Bool, AuthResponse?).self) { group in
                // First request
                group.addTask {
                    do {
                        let response = try await tester.execute(
                            uri: "/api/auth/refresh",
                            method: .post,
                            body: encodedBody
                        ) { response -> AuthResponse? in
                            if response.status == .created {
                                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
                            }
                            let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                            #expect(error.error.message.contains("Token has been revoked"))
                            return nil
                        }
                        return (1, response != nil, response)
                    } catch {
                        return (1, false, nil)
                    }
                }

                // Add a small delay to ensure the first request starts processing
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                // Second request - should fail as token is being processed
                group.addTask {
                    do {
                        let response = try await tester.execute(
                            uri: "/api/auth/refresh",
                            method: .post,
                            body: encodedBody
                        ) { response -> AuthResponse? in
                            if response.status == .created {
                                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
                            }
                            let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                            #expect(error.error.message.contains("Token has been revoked"))
                            return nil
                        }
                        return (2, response != nil, response)
                    } catch {
                        return (2, false, nil)
                    }
                }

                // Collect results
                var results: [(Int, Bool, AuthResponse?)] = []
                for try await result in group {
                    results.append(result)
                }
                return results.sorted { $0.0 < $1.0 }
            }

            // 4. Verify results - first request should succeed, second should fail
            #expect(results.count == 2)
            #expect(results[0].1 == true) // First request succeeds
            #expect(results[0].2 != nil) // First request has response
            #expect(results[1].1 == false) // Second request fails
            #expect(results[1].2 == nil) // Second request has no response

            // 5. Verify the successful token works
            if let newToken = results[0].2?.accessToken {
                try await tester.execute(
                    uri: "/api/auth/me",
                    method: .get,
                    auth: .bearer(newToken)
                ) { response in
                    #expect(response.status == .ok)
                }
            }

            // 6. Try to use the original token - should fail
            try await tester.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
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
                auth: .basic(username: "version@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Create JWT with incorrect version
            let jwtConfig = JWTConfiguration.load()
            let jwtID = UUID().uuidString
            let issuedAt = Date()
            let expirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)

            let payload = JWTPayloadData(
                subject: .init(value: authResponse.user.id.uuidString),
                expiration: .init(value: expirationDate),
                type: "access",
                issuer: jwtConfig.issuer,
                audience: jwtConfig.audience,
                issuedAt: issuedAt,
                id: jwtID,
                role: Role.customer.rawValue,
                tokenVersion: 999  // Invalid version
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

            // 3. Try to use token with wrong version
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(token)
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Token has been invalidated due to security changes"))
            }
        }
    }

    @Test("Should prevent token reuse after refresh")
    func testTokenReuseAfterRefresh() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Create and login user
            let requestBody = TestCreateUserRequest(
                username: "reuseuser",
                displayName: "Reuse Test User",
                email: "reuse@example.com",
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
                auth: .basic(username: "reuse@example.com", password: "K9#mP2$vL5nQ8*x")
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 2. Refresh token to get new pair
            let refreshResponse = try await client.execute(
                uri: "/api/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RefreshTokenRequest(refreshToken: authResponse.refreshToken),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 3. Try to use old access token
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken)
            ) { response in
                #expect(response.status == .unauthorized)
            }

            // 4. Try to use old refresh token again
            try await client.execute(
                uri: "/api/auth/refresh",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RefreshTokenRequest(refreshToken: authResponse.refreshToken),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Token has been revoked"))
            }

            // 5. Verify new tokens work
            try await client.execute(
                uri: "/api/auth/me",
                method: .get,
                auth: .bearer(refreshResponse.accessToken)
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }
}
