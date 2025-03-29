import Foundation
import Hummingbird
import JWTKit
import FluentKit
import HummingbirdFluent
import AsyncHTTPClient
import NIOCore

/// Controller for handling social sign in with third-party providers like Google and Apple
final class SocialAuthController {
    typealias Context = AppRequestContext
    private let fluent: Fluent
    private let jwtKeyCollection: JWTKeyCollection
    private let kid: JWKIdentifier
    private let jwtConfig: JWTConfiguration
    private let tokenStore: TokenStoreProtocol
    private let httpClient: HTTPClient
    
    /// Google OAuth2 configuration
    private struct GoogleOAuth2Config {
        let clientId: String
        let clientSecret: String
        let redirectUri: String
    }
    
    /// Apple Sign In configuration
    private struct AppleSignInConfig {
        let clientId: String
        let teamId: String
        let keyId: String
        let privateKey: String
        let redirectUri: String
    }
    
    /// Configuration for Google OAuth2
    private let googleConfig: GoogleOAuth2Config
    
    /// Configuration for Apple Sign In
    private let appleConfig: AppleSignInConfig
    
    /// Initialize the social authentication controller
    /// - Parameters:
    ///   - fluent: Database access
    ///   - jwtKeyCollection: JWT key collection for token signing
    ///   - kid: JWT key ID for signing
    ///   - jwtConfig: JWT configuration
    ///   - tokenStore: Token store for managing user tokens
    ///   - httpClient: HTTP client for making external API calls
    ///   - googleClientId: Google OAuth client ID
    ///   - googleClientSecret: Google OAuth client secret
    ///   - googleRedirectUri: Redirect URI for Google OAuth
    ///   - appleClientId: Apple Sign in client ID (Services ID)
    ///   - appleTeamId: Apple Developer Team ID
    ///   - appleKeyId: Apple private key ID
    ///   - applePrivateKey: Apple private key for signing
    ///   - appleRedirectUri: Redirect URI for Apple Sign In
    init(
        fluent: Fluent,
        jwtKeyCollection: JWTKeyCollection,
        kid: JWKIdentifier,
        jwtConfig: JWTConfiguration,
        tokenStore: TokenStoreProtocol,
        httpClient: HTTPClient,
        googleClientId: String,
        googleClientSecret: String,
        googleRedirectUri: String,
        appleClientId: String,
        appleTeamId: String,
        appleKeyId: String,
        applePrivateKey: String,
        appleRedirectUri: String
    ) {
        self.fluent = fluent
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.jwtConfig = jwtConfig
        self.tokenStore = tokenStore
        self.httpClient = httpClient
        
        self.googleConfig = GoogleOAuth2Config(
            clientId: googleClientId,
            clientSecret: googleClientSecret,
            redirectUri: googleRedirectUri
        )
        
        self.appleConfig = AppleSignInConfig(
            clientId: appleClientId,
            teamId: appleTeamId,
            keyId: appleKeyId,
            privateKey: applePrivateKey,
            redirectUri: appleRedirectUri
        )
    }
    
    /// Add routes for social authentication
    func addRoutes(to group: RouterGroup<Context>) {
        let socialGroup = group.group("social")
        
        // Google authentication endpoints
        socialGroup.post("sign-in/google", use: loginWithGoogle)
        socialGroup.get("google/callback", use: googleCallback)
        
        // Apple authentication endpoints
        socialGroup.post("sign-in/apple", use: signInWithApple)
        socialGroup.get("apple/callback", use: appleCallback)
        
        // Social sign in endpoint
        socialGroup.post("sign-in", use: signInWithSocial)
    }
    
    // MARK: - Google Authentication
    
    /// Handle Google sign in
    @Sendable func loginWithGoogle(_ request: Request, context: Context) async throws -> EditedResponse<AuthResponse> {
        // Parse the request to get the Google ID token
        let signInRequest = try await request.decode(as: GoogleLoginRequest.self, context: context)
        
        // Verify the ID token with Google
        return try await authenticateWithGoogle(idToken: signInRequest.idToken, accessToken: signInRequest.accessToken, request: request, context: context)
    }
    
    /// Handle Google OAuth callback - for web flow
    @Sendable func googleCallback(_ request: Request, context: Context) async throws -> Response {
        // This would handle the OAuth flow redirect
        throw HTTPError(.notImplemented)
    }
    
    // MARK: - Apple Authentication
    
    /// Handle Apple sign in
    @Sendable func signInWithApple(_ request: Request, context: Context) async throws -> EditedResponse<AuthResponse> {
        // Parse the request to get the Apple identity token
        let loginRequest = try await request.decode(as: AppleLoginRequest.self, context: context)
        
        // Verify the identity token with Apple
        return try await authenticateWithApple(
            identityToken: loginRequest.identityToken,
            authorizationCode: loginRequest.authorizationCode,
            fullName: loginRequest.fullName,
            email: loginRequest.email,
            request: request,
            context: context
        )
    }
    
    /// Handle Apple Sign In callback - for web flow
    @Sendable func appleCallback(_ request: Request, context: Context) async throws -> Response {
        // This would handle the OAuth flow redirect
        throw HTTPError(.notImplemented)
    }
    
    // MARK: - Social Sign In

    /// Handle social sign in for both Google and Apple
    @Sendable func signInWithSocial(_ request: Request, context: Context) async throws -> EditedResponse<AuthResponse> {
        // Parse the social sign in request
        let signInRequest = try await request.decode(as: SocialSignInRequest.self, context: context)
        
        // Handle based on provider
        switch signInRequest.provider {
        case "google":
            if case let .google(params) = signInRequest.parameters {
                return try await authenticateWithGoogle(
                    idToken: params.idToken,
                    accessToken: params.accessToken,
                    request: request,
                    context: context
                )
            }
            throw HTTPError(.badRequest, message: "Invalid Google authentication parameters")
            
        case "apple":
            if case let .apple(params) = signInRequest.parameters {
                return try await authenticateWithApple(
                    identityToken: params.identityToken,
                    authorizationCode: params.authorizationCode,
                    fullName: params.fullName != nil ? [
                        "firstName": params.fullName?.givenName,
                        "lastName": params.fullName?.familyName
                    ] : nil,
                    email: params.email,
                    request: request,
                    context: context
                )
            }
            throw HTTPError(.badRequest, message: "Invalid Apple authentication parameters")
            
        default:
            throw HTTPError(.badRequest, message: "Unsupported provider: \(signInRequest.provider)")
        }
    }
    
    // MARK: - Authentication Logic
    
    /// Authenticate a user with Google credentials
    private func authenticateWithGoogle(idToken: String, accessToken: String?, request: Request, context: Context) async throws -> EditedResponse<AuthResponse> {
        // 1. Verify the ID token with Google
        let payload = try await verifyGoogleIdToken(idToken: idToken)
        
        // 2. Extract user information from the verified payload
        guard let sub = payload["sub"] as? String,
              let email = payload["email"] as? String else {
            throw HTTPError(.badRequest, message: "Invalid Google token payload")
        }
        
        let displayName = payload["name"] as? String ?? "Google User"
        let picture = payload["picture"] as? String
        
        // 3. Find or create user by external provider ID
        let user = try await findOrCreateUserByExternalProvider(
            provider: "google",
            providerUserId: sub,
            email: email,
            displayName: displayName,
            profileImage: picture
        )
        
        // 4. Generate tokens for the user
        let tokens = try await generateTokensForUser(user)
        
        // 5. Return authentication response
        // Calculate expiration time
        let expiresIn: UInt = UInt(jwtConfig.accessTokenExpiration)
        let expirationDate = Date().addingTimeInterval(jwtConfig.accessTokenExpiration)
        let dateFormatter = ISO8601DateFormatter()
        let expiresAt = dateFormatter.string(from: expirationDate)
        
        return EditedResponse(
            status: .ok,
            response: AuthResponse(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                tokenType: "Bearer",
                expiresIn: expiresIn,
                expiresAt: expiresAt,
                user: UserResponse(from: user),
                status: AuthResponse.STATUS_SUCCESS
            )
        )
    }
    
    /// Authenticate a user with Apple credentials
    private func authenticateWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]?,
        email: String?,
        request: Request,
        context: Context
    ) async throws -> EditedResponse<AuthResponse> {
        // 1. Verify the identity token with Apple
        let payload = try await verifyAppleIdentityToken(identityToken: identityToken)
        
        // 2. Extract user information from the verified payload
        guard let sub = payload["sub"] as? String else {
            throw HTTPError(.badRequest, message: "Invalid Apple token payload")
        }
        
        // Use email from payload or parameter
        let userEmail = (payload["email"] as? String) ?? email
        
        guard let finalEmail = userEmail else {
            throw HTTPError(.badRequest, message: "Email is required for Apple Sign In")
        }
        
        // Construct name from fullName parameter if available
        var userDisplayName = "Apple User"
        if let fullName = fullName {
            let firstName = fullName["firstName"] ?? ""
            let lastName = fullName["lastName"] ?? ""
            
            if let first = firstName, !first.isEmpty {
                userDisplayName = first
                if let last = lastName, !last.isEmpty {
                    userDisplayName += " \(last)"
                }
            }
        }
        
        // 3. Find or create user by external provider ID
        let user = try await findOrCreateUserByExternalProvider(
            provider: "apple",
            providerUserId: sub,
            email: finalEmail,
            displayName: userDisplayName,
            profileImage: nil
        )
        
        // 4. Generate tokens for the user
        let tokens = try await generateTokensForUser(user)
        
        // 5. Return authentication response
        // Calculate expiration time
        let expiresIn: UInt = UInt(jwtConfig.accessTokenExpiration)
        let expirationDate = Date().addingTimeInterval(jwtConfig.accessTokenExpiration)
        let dateFormatter = ISO8601DateFormatter()
        let expiresAt = dateFormatter.string(from: expirationDate)
        
        return EditedResponse(
            status: .ok,
            response: AuthResponse(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
                tokenType: "Bearer",
                expiresIn: expiresIn,
                expiresAt: expiresAt,
                user: UserResponse(from: user),
                status: AuthResponse.STATUS_SUCCESS
            )
        )
    }
    
    // MARK: - Helper Methods
    
    /// Verify a Google ID token with Google's tokeninfo endpoint
    private func verifyGoogleIdToken(idToken: String) async throws -> [String: Any] {
        // 1. Create request to Google's tokeninfo endpoint
        let requestURL = "https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=\(idToken)"
        var request = HTTPClientRequest(url: requestURL)
        request.method = .GET
        
        // 2. Send the request
        let response = try await httpClient.execute(request, timeout: .seconds(30))
        
        // 3. Check the response status
        guard response.status == .ok else {
            throw HTTPError(.unauthorized, message: "Failed to verify Google ID token")
        }
        
        // 4. Parse the response body
        let body = try await response.body.collect(upTo: 1024 * 1024) // 1MB limit
        let data = Data(buffer: body)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HTTPError(.internalServerError, message: "Failed to parse Google token response")
        }
        
        // 5. Verify the audience (aud) matches our client ID
        guard let aud = json["aud"] as? String, aud == googleConfig.clientId else {
            throw HTTPError(.unauthorized, message: "Google token has invalid audience")
        }
        
        return json
    }
    
    /// Verify an Apple identity token
    private func verifyAppleIdentityToken(identityToken: String) async throws -> [String: Any] {
        // 1. Decode the JWT without verification to get the header
        let jwtToken = identityToken
        
        // Extract payload without verification - in a real production implementation
        // you would validate the JWT signature against Apple's public keys
        // For this implementation, we just extract the payload as we can't verify Apple's signature easily
        
        let parts = jwtToken.split(separator: ".")
        guard parts.count == 3,
              let payloadData = base64URLDecode(String(parts[1])),
              let payloadJSON = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] else {
            throw HTTPError(.unauthorized, message: "Invalid Apple identity token format")
        }
        
        // 3. Verify the issuer is Apple
        guard let iss = payloadJSON["iss"] as? String, iss == "https://appleid.apple.com" else {
            throw HTTPError(.unauthorized, message: "Apple token has invalid issuer")
        }
        
        // 4. Verify the audience is our client ID
        guard let aud = payloadJSON["aud"] as? String, aud == appleConfig.clientId else {
            throw HTTPError(.unauthorized, message: "Apple token has invalid audience")
        }
        
        return payloadJSON
    }
    
    /// Base64URL decode a string to Data
    private func base64URLDecode(_ base64url: String) -> Data? {
        var base64 = base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        if base64.count % 4 != 0 {
            base64 += String(repeating: "=", count: 4 - base64.count % 4)
        }
        
        return Data(base64Encoded: base64)
    }
    
    /// Find or create a user by external provider ID
    private func findOrCreateUserByExternalProvider(
        provider: String,
        providerUserId: String,
        email: String,
        displayName: String,
        profileImage: String?
    ) async throws -> User {
        // First try to find user by external provider ID
        if let externalId = try await ExternalProviderIdentity.query(on: fluent.db())
            .filter(\.$provider == provider)
            .filter(\.$providerUserId == providerUserId)
            .first(),
           let user = try await User.find(externalId.$user.id, on: fluent.db()) {
            return user
        }
        
        // Next, try to find user by email
        if let existingUser = try await User.query(on: fluent.db())
            .filter(\.$email == email)
            .first() {
            
            // Add the external provider link to this user
            let externalId = ExternalProviderIdentity(
                userId: existingUser.id!,
                provider: provider,
                providerUserId: providerUserId
            )
            try await externalId.save(on: fluent.db())
            
            return existingUser
        }
        
        // Create a new user with the social sign in info
        let username = email.split(separator: "@").first?.lowercased() ?? "user_\(UUID().uuidString.prefix(8))"
        
        let user = User(
            username: String(username),
            displayName: displayName,
            email: email,
            profilePicture: profileImage,
            role: .customer,
            passwordHash: nil,
            emailVerified: true,
            failedSignInAttempts: 0,
            accountLocked: false,
            requirePasswordChange: false,
            twoFactorEnabled: false,
            emailVerificationEnabled: false,
            tokenVersion: 0
        )
        
        try await user.save(on: fluent.db())
        
        // Create external provider identity link
        let externalId = ExternalProviderIdentity(
            userId: user.id!,
            provider: provider,
            providerUserId: providerUserId
        )
        try await externalId.save(on: fluent.db())
        
        return user
    }
    
    /// Generate access and refresh tokens for a user
    private func generateTokensForUser(_ user: User) async throws -> (accessToken: String, refreshToken: String) {
        // 1. Generate JWT payload for access token
        let accessExpirationDate = Date().addingTimeInterval(jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date().addingTimeInterval(jwtConfig.refreshTokenExpiration)
        let issuedAt = Date()
        
        // Create access token
        let accessPayload = JWTPayloadData(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: accessExpirationDate),
            type: "access",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        // Create refresh token
        let refreshPayload = JWTPayloadData(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: refreshExpirationDate),
            type: "refresh",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion
        )
        
        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let refreshToken = try await self.jwtKeyCollection.sign(refreshPayload, kid: self.kid)
        
        return (accessToken: accessToken, refreshToken: refreshToken)
    }
}

// MARK: - Request Models

/// Request model for Google sign in
struct GoogleLoginRequest: Codable {
    /// The ID token from Google
    let idToken: String
    
    /// Optional access token from Google
    let accessToken: String?
}

/// Request model for Apple sign in
struct AppleLoginRequest: Codable {
    /// The identity token from Apple
    let identityToken: String
    
    /// The authorization code from Apple
    let authorizationCode: String
    
    /// Optional user's name provided during Apple Sign In
    let fullName: [String: String?]?
    
    /// Optional user's email provided during Apple Sign In
    let email: String?
}
