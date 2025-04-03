import Foundation
import Hummingbird
import HummingbirdFluent
import JWTKit
import FluentKit

/// Controller for handling OAuth 2.0 endpoints
struct OAuthController {
    typealias Context = AppRequestContext
    let fluent: Fluent
    let jwtKeyCollection: JWTKeyCollection
    let kid: JWKIdentifier
    let jwtConfig: JWTConfiguration
    let tokenStore: TokenStoreProtocol
    
    init(fluent: Fluent, jwtKeyCollection: JWTKeyCollection, kid: JWKIdentifier, jwtConfig: JWTConfiguration, tokenStore: TokenStoreProtocol) {
        self.fluent = fluent
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.jwtConfig = jwtConfig
        self.tokenStore = tokenStore
    }
    
    /// Add routes for OAuth server functionality
    func addRoutes(to group: RouterGroup<AppRequestContext>) {
        // Client registration endpoints
        let clientsGroup = group.group("clients")
        clientsGroup.add(middleware: JWTAuthenticator(fluent: fluent, tokenStore: tokenStore))
        clientsGroup.get(use: listClients)
            .post(use: createClient)
            .get(":clientId", use: getClient)
            .put(":clientId", use: updateClient)
            .delete(":clientId", use: deleteClient)
        
        // OAuth endpoints (publicly accessible)
        group.get("authorize", use: authorize)
            .post("token", use: token)
    }
    
    /// Add public routes (no authentication required)
    func addPublicRoutes(to group: RouterGroup<Context>) {
        // OAuth endpoints (publicly accessible)
        group.get("authorize", use: authorize)
            .post("token", use: token)
    }
    
    /// Add protected routes (require authentication)
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        // Client registration endpoints
        group.get(use: listClients)
            .post(use: createClient)
            .get(":clientId", use: getClient)
            .put(":clientId", use: updateClient)
            .delete(":clientId", use: deleteClient)
    }
    
    // MARK: - Client Management Endpoints
    
    /// List registered OAuth clients (admin only)
    @Sendable func listClients(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<OAuthClientListResponse> {
        // Ensure admin permissions
        guard let user = context.identity, user.role == .admin else {
            throw HTTPError(.forbidden, message: "Admin access required")
        }
        
        let clients = try await OAuthClient.query(on: fluent.db())
            .all()
        
        let response = OAuthClientListResponse(
            clients: clients.map { OAuthClientResponse(from: $0) },
            count: clients.count
        )
        
        return .init(
            status: .ok,
            response: response
        )
    }
    
    // Define ClientWithSecret struct at the controller level
    struct ClientWithSecret: Codable, ResponseEncodable {
        let client: OAuthClientResponse
        let clientSecret: String
    }
    
    /// Create a new OAuth client (admin only)
    @Sendable func createClient(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<ClientWithSecret> {
        // Ensure admin permissions
        guard let user = context.identity, user.role == .admin else {
            throw HTTPError(.forbidden, message: "Admin access required")
        }
        
        let createRequest = try await request.decode(as: CreateOAuthClientRequest.self, context: context)
        
        // Generate client credentials
        let (clientId, clientSecret) = OAuthClient.generateCredentials()
        
        // Create the client
        let client = OAuthClient(
            clientId: clientId,
            clientSecret: clientSecret,
            name: createRequest.name,
            redirectURIs: createRequest.redirectURIs,
            allowedGrantTypes: createRequest.allowedGrantTypes,
            allowedScopes: createRequest.allowedScopes,
            isPublic: createRequest.isPublic ?? false,
            description: createRequest.description,
            websiteURL: createRequest.websiteURL,
            logoURL: createRequest.logoURL
        )
        
        try await client.save(on: fluent.db())
        
        // Create response that includes the client secret (only shown once)
        let response = OAuthClientResponse(from: client)
        
        return .init(
            status: .created,
            response: ClientWithSecret(
                client: response,
                clientSecret: clientSecret
            )
        )
    }
    
    /// Get details for a specific OAuth client (admin only)
    @Sendable func getClient(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<OAuthClientResponse> {
        // Ensure admin permissions
        guard let user = context.identity, user.role == .admin else {
            throw HTTPError(.forbidden, message: "Admin access required")
        }
        
        // Extract client ID from path parameters
        guard let clientIdStr = request.uri.path.split(separator: "/").last.map({ String($0) }) else {
            throw HTTPError(.badRequest, message: "Missing client ID")
        }
        
        // Find the client
        guard let client = try await OAuthClient.query(on: fluent.db())
            .filter(\.$clientId, .equal, clientIdStr)
            .first() else {
            throw HTTPError(.notFound, message: "Client not found")
        }
        
        return .init(
            status: .ok,
            response: OAuthClientResponse(from: client)
        )
    }
    
    /// Update an existing OAuth client (admin only)
    @Sendable func updateClient(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<OAuthClientResponse> {
        // Ensure admin permissions
        guard let user = context.identity, user.role == .admin else {
            throw HTTPError(.forbidden, message: "Admin access required")
        }
        
        // Extract client ID from path parameters
        guard let clientIdStr = request.uri.path.split(separator: "/").last.map({ String($0) }) else {
            throw HTTPError(.badRequest, message: "Missing client ID")
        }
        
        // Find the client
        guard let client = try await OAuthClient.query(on: fluent.db())
            .filter(\.$clientId, .equal, clientIdStr)
            .first() else {
            throw HTTPError(.notFound, message: "Client not found")
        }
        
        // Decode update request
        let updateRequest = try await request.decode(as: UpdateClientRequest.self, context: context)
        
        // Apply updates
        if let name = updateRequest.name {
            client.name = name
        }
        
        if let redirectURIs = updateRequest.redirectURIs {
            client.redirectURIs = redirectURIs
        }
        
        if let allowedGrantTypes = updateRequest.allowedGrantTypes {
            client.allowedGrantTypes = allowedGrantTypes
        }
        
        if let allowedScopes = updateRequest.allowedScopes {
            client.allowedScopes = allowedScopes
        }
        
        if let isActive = updateRequest.isActive {
            client.isActive = isActive
        }
        
        client.description = updateRequest.description ?? client.description
        client.websiteURL = updateRequest.websiteURL ?? client.websiteURL
        client.logoURL = updateRequest.logoURL ?? client.logoURL
        
        try await client.save(on: fluent.db())
        
        return .init(
            status: .ok,
            response: OAuthClientResponse(from: client)
        )
    }
    
    /// Delete an OAuth client (admin only)
    @Sendable func deleteClient(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Ensure admin permissions
        guard let user = context.identity, user.role == .admin else {
            throw HTTPError(.forbidden, message: "Admin access required")
        }
        
        // Extract client ID from path parameters
        guard let clientIdStr = request.uri.path.split(separator: "/").last.map({ String($0) }) else {
            throw HTTPError(.badRequest, message: "Missing client ID")
        }
        
        // Find the client
        guard let client = try await OAuthClient.query(on: fluent.db())
            .filter(\.$clientId, .equal, clientIdStr)
            .first() else {
            throw HTTPError(.notFound, message: "Client not found")
        }
        
        // Delete the client
        try await client.delete(on: fluent.db())
        
        return .init(
            status: .ok,
            response: MessageResponse(
                message: "OAuth client deleted successfully",
                success: true
            )
        )
    }
    
    // MARK: - OAuth Endpoints
    
    /// Authorization endpoint for the OAuth 2.0 Authorization Code Flow
    @Sendable func authorize(
        _ request: Request,
        context: Context
    ) async throws -> Response {
        // Extract OAuth parameters from query
        guard let clientIdParam = request.uri.queryParameters.first(where: { $0.key == "client_id" })?.value else {
            throw HTTPError(.badRequest, message: "Missing client_id parameter")
        }
        // Convert Substring to String
        let clientId = String(clientIdParam)
        
        guard let redirectURIParamSub = request.uri.queryParameters.first(where: { $0.key == "redirect_uri" })?.value else {
            throw HTTPError(.badRequest, message: "Missing redirect_uri parameter")
        }
        // Convert Substring to String
        let redirectURIParam = String(redirectURIParamSub)
        
        guard let responseTypeSub = request.uri.queryParameters.first(where: { $0.key == "response_type" })?.value,
              String(responseTypeSub) == "code" else {
            throw HTTPError(.badRequest, message: "Only response_type=code is supported")
        }
        
        // Get state parameter (optional but recommended)
        let stateSub = request.uri.queryParameters.first(where: { $0.key == "state" })?.value
        let state = stateSub.map { String($0) }
        
        // Get scope parameter (optional)
        let scopeParamSub = request.uri.queryParameters.first(where: { $0.key == "scope" })?.value
        let scopeParam = scopeParamSub.map { String($0) }
        let scopes = scopeParam?.split(separator: " ").map { String($0) } ?? ["basic"]
        
        // Get PKCE parameters (optional)
        let codeChallengeSub = request.uri.queryParameters.first(where: { $0.key == "code_challenge" })?.value
        let codeChallenge = codeChallengeSub.map { String($0) }
        
        let codeChallengeMethodSub = request.uri.queryParameters.first(where: { $0.key == "code_challenge_method" })?.value
        let codeChallengeMethod = codeChallengeMethodSub.map { String($0) }
        
        // Look up the client
        guard let client = try await OAuthClient.query(on: fluent.db())
            .filter(\.$clientId, .equal, clientId)
            .filter(\.$isActive, .equal, true)
            .first() else {
            throw HTTPError(.unauthorized, message: "Invalid client")
        }
        
        // Validate redirect URI
        guard client.validateRedirectURI(redirectURIParam) else {
            throw HTTPError(.badRequest, message: "Invalid redirect URI")
        }
        
        // Check if user is already authenticated
        guard let user = context.identity else {
            // Not authenticated, redirect to sign in with return URL
            // We need to create a return URL that brings the user back to this authorize endpoint
            let path = request.uri.path
            var returnURL = String(path)
            if let querySub = request.uri.query {
                let query = String(querySub)
                returnURL += "?" + query
            }
            
            let encodedReturnURL = returnURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let loginURL = "/api/v1/auth/sign-in?return_url=\(encodedReturnURL)"
            
            return Response(
                status: .seeOther,
                headers: [.location: loginURL]
            )
        }
        
        // At this point, user is authenticated
        // Generate an authorization code
        let code = AuthorizationCode.generateCode()
        
        // Create authorization code record
        let authCode = AuthorizationCode(
            code: code,
            clientId: clientId, 
            userId: try user.requireID(),
            redirectURI: redirectURIParam,
            scopes: scopes,
            codeChallenge: codeChallenge,
            codeChallengeMethod: codeChallengeMethod,
            expiresAt: Date().addingTimeInterval(600), // 10 minute expiration
            state: state
        )
        
        try await authCode.save(on: fluent.db())
        
        // Construct redirect URL with code and state
        if let _ = URL(string: redirectURIParam) {
            // Create a string for the URL
            var redirectURLString = redirectURIParam
            
            // Add the query parameters manually
            redirectURLString += redirectURLString.contains("?") ? "&" : "?"
            redirectURLString += "code=\(code)"
            
            // Add the state parameter if present
            if let stateValue = state {
                redirectURLString += "&state=\(stateValue)"
            }
            
            // Create the response with the URL
            return Response(
                status: .seeOther,
                headers: [.location: redirectURLString]
            )
        } else {
            throw HTTPError(.internalServerError, message: "Failed to construct redirect URL")
        }
    }
    
    // Define TokenResponse at the controller level
    struct TokenResponse: Codable, ResponseEncodable {
        let accessToken: String
        let tokenType: String
        let expiresIn: Int
        let refreshToken: String?
        let scope: String
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case tokenType = "token_type"
            case expiresIn = "expires_in"
            case refreshToken = "refresh_token"
            case scope
        }
    }
    
    // Define TokenRequestBase struct at the controller level
    struct TokenRequestBase: Decodable {
        let grantType: String
        
        enum CodingKeys: String, CodingKey {
            case grantType = "grant_type"
        }
    }
    
    // Define types needed for client authentication
    struct ClientCredentialsRequest: Decodable {
        let clientId: String
        let clientSecret: String?
        
        enum CodingKeys: String, CodingKey {
            case clientId = "client_id"
            case clientSecret = "client_secret"
        }
    }
    
    // Define request type for authorization code grant
    struct AuthCodeRequest: Decodable {
        let code: String
        let redirectUri: String
        let codeVerifier: String?
        
        enum CodingKeys: String, CodingKey {
            case code
            case redirectUri = "redirect_uri"
            case codeVerifier = "code_verifier"
        }
    }
    
    // Define request type for refresh token grant
    struct RefreshTokenRequest: Decodable {
        let refreshToken: String
        let scope: String?
        
        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
            case scope
        }
    }
    
    /// Token endpoint for exchanging authorization code for tokens
    @Sendable func token(
        _ request: Request,
        context: Context
    ) async throws -> Response {
        // Verify client authentication using HTTP Basic Auth if provided, or client_id/client_secret in body
        let clientAuth = try await authenticateClient(request, context: context)
        
        // Extract grant type
        let baseRequest = try await request.decode(as: TokenRequestBase.self, context: context)
        
        // Handle different grant types
        switch baseRequest.grantType {
        case "authorization_code":
            // Get token response directly
            let tokenResponse = try await handleAuthorizationCodeGrant(request, context: context, clientAuth: clientAuth)
            
            // Create standard JSON response
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(tokenResponse)
            var buffer = ByteBuffer()
            buffer.writeData(jsonData)
            
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: buffer)
            )
            
        case "refresh_token":
            // Get token response directly
            let tokenResponse = try await handleRefreshTokenGrant(request, context: context, clientAuth: clientAuth)
            
            // Create standard JSON response
            let encoder = JSONEncoder()
            let jsonData = try encoder.encode(tokenResponse)
            var buffer = ByteBuffer()
            buffer.writeData(jsonData)
            
            return Response(
                status: .ok,
                headers: [.contentType: "application/json"],
                body: .init(byteBuffer: buffer)
            )
            
        case "client_credentials":
            // Not implemented in this initial version
            throw HTTPError(.badRequest, message: "Unsupported grant type: client_credentials")
            
        default:
            throw HTTPError(.badRequest, message: "Unsupported grant type: \(baseRequest.grantType)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Authenticate client using HTTP Basic Auth or client credentials in body
    private func authenticateClient(
        _ request: Request,
        context: Context
    ) async throws -> (client: OAuthClient, isPublic: Bool) {
        // Check for HTTP Basic Auth first
        if let basic = request.headers.basic {
            // Lookup client
            guard let client = try await OAuthClient.query(on: fluent.db())
                .filter(\.$clientId, .equal, basic.username)
                .filter(\.$isActive, .equal, true)
                .first() else {
                throw HTTPError(.unauthorized, message: "Invalid client")
            }
            
            // For confidential clients, verify the secret
            if !client.isPublic {
                guard let clientSecret = client.clientSecret,
                      basic.password == clientSecret else {
                    throw HTTPError(.unauthorized, message: "Invalid client secret")
                }
            }
            
            return (client, client.isPublic)
        }
        
        // Check for client_id in request body if no Basic Auth
        do {
            let credentials = try await request.decode(as: ClientCredentialsRequest.self, context: context)
            
            // Lookup client
            guard let client = try await OAuthClient.query(on: fluent.db())
                .filter(\.$clientId, .equal, credentials.clientId)
                .filter(\.$isActive, .equal, true)
                .first() else {
                throw HTTPError(.unauthorized, message: "Invalid client")
            }
            
            // For confidential clients, verify the secret
            if !client.isPublic {
                guard let clientSecret = client.clientSecret,
                      let providedSecret = credentials.clientSecret,
                      providedSecret == clientSecret else {
                    throw HTTPError(.unauthorized, message: "Invalid client secret")
                }
            }
            
            return (client, client.isPublic)
        } catch {
            // Neither Basic Auth nor client_id/client_secret in body
            throw HTTPError(.unauthorized, message: "Client authentication required")
        }
    }
    
    /// Handle the authorization_code grant type
    private func handleAuthorizationCodeGrant(
        _ request: Request,
        context: Context,
        clientAuth: (client: OAuthClient, isPublic: Bool)
    ) async throws -> TokenResponse {
        // Extract grant-specific parameters
        let tokenRequest = try await request.decode(as: AuthCodeRequest.self, context: context)
        
        // Look up the authorization code
        guard let authCode = try await AuthorizationCode.query(on: fluent.db())
            .filter(\.$code, .equal, tokenRequest.code)
            .filter(\.$isUsed, .equal, false)
            .first() else {
            throw HTTPError(.badRequest, message: "Invalid authorization code")
        }
        
        // Verify the client ID matches
        guard authCode.clientId == clientAuth.client.clientId else {
            throw HTTPError(.unauthorized, message: "Authorization code was not issued to this client")
        }
        
        // Verify the redirect URI matches
        guard authCode.redirectURI == tokenRequest.redirectUri else {
            throw HTTPError(.badRequest, message: "Redirect URI mismatch")
        }
        
        // Verify the code is not expired
        guard !authCode.isExpired else {
            throw HTTPError(.badRequest, message: "Authorization code has expired")
        }
        
        // For public clients or clients using PKCE, verify the code verifier
        if authCode.codeChallenge != nil || clientAuth.isPublic {
            guard let codeVerifier = tokenRequest.codeVerifier else {
                throw HTTPError(.badRequest, message: "code_verifier is required")
            }
            
            guard authCode.verifyCodeVerifier(codeVerifier) else {
                throw HTTPError(.badRequest, message: "Invalid code_verifier")
            }
        }
        
        // Mark the code as used
        authCode.isUsed = true
        try await authCode.save(on: fluent.db())
        
        // Look up the user
        guard let user = try await User.find(authCode.$user.id, on: fluent.db()) else {
            throw HTTPError(.internalServerError, message: "User not found")
        }
        
        // Generate tokens
        let accessExpirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date(timeIntervalSinceNow: jwtConfig.refreshTokenExpiration)
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
            tokenVersion: user.tokenVersion,
            scope: authCode.scopes.joined(separator: " "),
            clientId: clientAuth.client.clientId
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
            tokenVersion: user.tokenVersion,
            scope: authCode.scopes.joined(separator: " "),
            clientId: clientAuth.client.clientId
        )
        
        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let refreshToken = try await self.jwtKeyCollection.sign(refreshPayload, kid: self.kid)
        
        // Create token response
        return TokenResponse(
            accessToken: accessToken,
            tokenType: "Bearer",
            expiresIn: Int(jwtConfig.accessTokenExpiration),
            refreshToken: refreshToken,
            scope: authCode.scopes.joined(separator: " ")
        )
    }
    
    /// Handle the refresh_token grant type
    private func handleRefreshTokenGrant(
        _ request: Request,
        context: Context,
        clientAuth: (client: OAuthClient, isPublic: Bool)
    ) async throws -> TokenResponse {
        // Extract refresh token
        let refreshRequest = try await request.decode(as: RefreshTokenRequest.self, context: context)
        
        // Verify refresh token is not blacklisted
        if await tokenStore.isBlacklisted(refreshRequest.refreshToken) {
            throw HTTPError(.unauthorized, message: "Token has been revoked")
        }
        
        // Verify and decode refresh token
        let refreshPayload = try await self.jwtKeyCollection.verify(refreshRequest.refreshToken, as: JWTPayloadData.self)
        
        // Ensure it's a refresh token
        guard refreshPayload.type == "refresh" else {
            throw HTTPError(.unauthorized, message: "Invalid token type")
        }
        
        // Get user from database
        guard let user = try await User.find(UUID(uuidString: refreshPayload.subject.value), on: fluent.db()) else {
            throw HTTPError(.unauthorized, message: "User not found")
        }
        
        // Verify token version
        guard let tokenVersion = refreshPayload.tokenVersion,
              tokenVersion == user.tokenVersion else {
            throw HTTPError(.unauthorized, message: "Invalid token version")
        }
        
        // Blacklist the used refresh token
        await tokenStore.blacklist(refreshRequest.refreshToken, expiresAt: refreshPayload.expiration.value, reason: .tokenVersionChange)
        
        // Generate new tokens
        let accessExpirationDate = Date(timeIntervalSinceNow: jwtConfig.accessTokenExpiration)
        let refreshExpirationDate = Date(timeIntervalSinceNow: jwtConfig.refreshTokenExpiration)
        let issuedAt = Date()
        
        // Create access token
        let accessPayload = JWTPayloadData(
            subject: SubjectClaim(value: refreshPayload.subject.value),
            expiration: ExpirationClaim(value: accessExpirationDate),
            type: "access",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion,
            scope: refreshPayload.scope,
            clientId: refreshPayload.clientId
        )
        
        // Create refresh token with same version
        let newRefreshPayload = JWTPayloadData(
            subject: SubjectClaim(value: refreshPayload.subject.value),
            expiration: ExpirationClaim(value: refreshExpirationDate),
            type: "refresh",
            issuer: jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: UUID().uuidString,
            role: user.role.rawValue,
            tokenVersion: user.tokenVersion,
            scope: refreshPayload.scope,
            clientId: refreshPayload.clientId
        )
        
        let accessToken = try await self.jwtKeyCollection.sign(accessPayload, kid: self.kid)
        let newRefreshToken = try await self.jwtKeyCollection.sign(newRefreshPayload, kid: self.kid)
        
        // Use requested scope or original scope
        let scope = refreshRequest.scope ?? refreshPayload.scope ?? "basic" 
        
        // Create token response
        return TokenResponse(
            accessToken: accessToken,
            tokenType: "Bearer",
            expiresIn: Int(jwtConfig.accessTokenExpiration),
            refreshToken: newRefreshToken,
            scope: scope
        )
    }
}

// Move nested struct out of controller method
struct UpdateClientRequest: Codable {
    let name: String?
    let redirectURIs: [String]?
    let allowedGrantTypes: [String]?
    let allowedScopes: [String]?
    let isActive: Bool?
    let description: String?
    let websiteURL: String?
    let logoURL: String?
    
    enum CodingKeys: String, CodingKey {
        case name
        case redirectURIs = "redirect_uris"
        case allowedGrantTypes = "allowed_grant_types"
        case allowedScopes = "allowed_scopes"
        case isActive = "is_active"
        case description
        case websiteURL = "website_url"
        case logoURL = "logo_url"
    }
} 
