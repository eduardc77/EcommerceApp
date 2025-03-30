@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import JWTKit

@Suite("Social Authentication Tests")
struct SocialAuthenticationTests {
    @Test("Google authentication returns 401 for mock tokens")
    func testGoogleAuthentication() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Create a test request with mock token
            let requestBody = SocialSignInRequest(
                provider: "google", 
                parameters: .google(GoogleAuthParams(
                    idToken: "mock_google_id_token", 
                    accessToken: "mock_access_token"
                ))
            )
            
            try await client.execute(
                uri: "/api/v1/auth/social/sign-in",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                // Without special handling, mock tokens should be rejected with 401
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Apple authentication returns 401 for mock tokens")
    func testAppleAuthentication() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Create a test request with mock token
            let fullName = AppleNameComponents(givenName: "Apple", familyName: "User")
            
            let requestBody = SocialSignInRequest(
                provider: "apple",
                parameters: .apple(AppleAuthParams(
                    identityToken: "mock_apple_identity_token",
                    authorizationCode: "mock_authorization_code",
                    fullName: fullName,
                    email: "apple_test@example.com"
                ))
            )
            
            try await client.execute(
                uri: "/api/v1/auth/social/sign-in",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                // Without special handling, mock tokens should be rejected with 401
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Social sign in with existing user returns 401 for mock tokens")
    func testSocialLoginWithExistingUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Sign up a regular user first
            let email = "social_existing@example.com"
            let requestBody = TestSignUpRequest(
                username: "social_existing",
                displayName: "Existing User",
                email: email,
                password: "TestingV@lid143!#",
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
            try await client.completeEmailVerification(email: email)
            
            // Sign in with the user to verify account is active
            let initialAuth = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: email, password: "TestingV@lid143!#")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                return authResponse
            }
            
            // Verify initial sign in works
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(initialAuth.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let user = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(user.username == "social_existing")
            }
            
            // 2. Now perform a Google sign in with the same email
            let socialRequestBody = SocialSignInRequest(
                provider: "google",
                parameters: .google(GoogleAuthParams(
                    idToken: "mock_google_token_for_\(email)",
                    accessToken: "mock_access_token"
                ))
            )
            
            try await client.execute(
                uri: "/api/v1/auth/social/sign-in",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(socialRequestBody, allocator: ByteBufferAllocator())
            ) { response in
                // Without special handling, mock tokens should be rejected with 401
                #expect(response.status == .unauthorized)
            }
        }
    }
    
    @Test("Invalid provider returns error")
    func testInvalidProvider() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Construct a request with an invalid provider
            let badRequest = """
            {
                "provider": "invalid_provider",
                "parameters": {
                    "type": "google",
                    "data": {
                        "idToken": "invalid_token",
                        "accessToken": null
                    }
                }
            }
            """
            
            try await client.execute(
                uri: "/api/v1/auth/social/sign-in",
                method: .post,
                body: ByteBuffer(string: badRequest)
            ) { response in
                #expect(response.status == .badRequest)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Unsupported provider"))
            }
        }
    }
} 
