@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import JWTKit

@Suite("OpenID Connect Tests")
struct OIDCTests {
    @Test("Can access JWKS endpoint")
    func testJWKSEndpoint() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/.well-known/jwks.json",
                method: .get
            ) { response in
                #expect(response.status == .ok)
                let jwksResponse = try JSONDecoder().decode(JWKSResponse.self, from: response.body)
                #expect(!jwksResponse.keys.isEmpty)

                // Verify the key has the required properties
                let key = jwksResponse.keys.first!
                #expect(key.kty == "oct")
                #expect(key.use == "sig")
                #expect(key.kid == "hb_local")
                #expect(key.alg == "HS256")
            }
        }
    }

    @Test("Can access OpenID configuration endpoint")
    func testOpenIDConfigurationEndpoint() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/.well-known/openid-configuration",
                method: .get
            ) { response in
                #expect(response.status == .ok)
                let config = try JSONDecoder().decode(OIDCConfiguration.self, from: response.body)

                // Verify required fields
                #expect(!config.issuer.isEmpty)
                #expect(!config.jwksUri.isEmpty)
                #expect(!config.responseTypesSupported.isEmpty)
                #expect(!config.subjectTypesSupported.isEmpty)
                #expect(!config.idTokenSigningAlgValuesSupported.isEmpty)

                // Verify JWKS URI is correct
                #expect(config.jwksUri.contains("/.well-known/jwks.json"))
            }
        }
    }

    @Test("Can access UserInfo endpoint with valid token")
    func testUserInfoEndpoint() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Sign up user
            let requestBody = TestSignUpRequest(
                username: "oidctest",
                displayName: "OIDC Test User",
                email: "oidctest@example.com",
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
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)

            // 3. Sign in to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Access UserInfo endpoint with valid token
            try await client.execute(
                uri: "/api/v1/auth/userinfo",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let userInfo = try JSONDecoder().decode(UserInfoResponse.self, from: response.body)

                // Verify UserInfo contains standard claims
                #expect(userInfo.sub == authResponse.user!.id)
                #expect(userInfo.name == requestBody.displayName)
                #expect(userInfo.email == requestBody.email)
                #expect(userInfo.emailVerified == true)
                #expect(userInfo.picture != nil)
                #expect(userInfo.role == "customer")
            }
        }
    }

    @Test("UserInfo endpoint requires authentication")
    func testUserInfoEndpointRequiresAuth() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/auth/userinfo",
                method: .get
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("UserInfo endpoint returns error for invalid token")
    func testUserInfoEndpointWithInvalidToken() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            try await client.execute(
                uri: "/api/v1/auth/userinfo",
                method: .get,
                auth: .bearer("invalid-token")
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("UserInfo endpoint returns error for expired token")
    func testUserInfoEndpointWithExpiredToken() async throws {
        let app = try await buildApplication(TestAppArguments())

        try await app.test(.router) { client in
            // 1. Sign up user
            let requestBody = TestSignUpRequest(
                username: "expiredtest",
                displayName: "Expired Token Test User",
                email: "expiredtest@example.com",
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
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)

            // 3. Sign in to get user ID
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }

            // 4. Generate an expired token
            let expiredToken = try await JWTKeyCollection.generateTestToken(
                subject: authResponse.user!.id,
                expiration: Date(timeIntervalSinceNow: -3600) // Expired 1 hour ago
            )

            // 5. Try to access UserInfo endpoint with expired token
            try await client.execute(
                uri: "/api/v1/auth/userinfo",
                method: .get,
                auth: .bearer(expiredToken)
            ) { response in
                #expect(response.status == .unauthorized)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Token has expired"))
            }
        }
    }
}
