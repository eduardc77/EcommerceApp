import Foundation

public protocol AuthorizationManagerProtocol: Actor {
    func getValidToken() async throws -> OAuthToken
    func invalidateToken() async throws
}

public actor AuthorizationManager: AuthorizationManagerProtocol {
    private var refreshTask: Task<OAuthToken, Error>?
    private let tokenStore: TokenStoreProtocol
    private var apiClient: APIClient?
    
    public init(tokenStore: TokenStoreProtocol) {
        self.tokenStore = tokenStore
    }
    
    public func setAPIClient(_ client: APIClient) {
        self.apiClient = client
    }
    
    public func getValidToken() async throws -> OAuthToken {
        // Get current token
        guard let token = try await tokenStore.getToken() else {
            throw NetworkError.missingToken(description: "No token found")
        }
        
        // Return if token is still valid
        if token.isAccessTokenValid {
            return token
        }
        
        // Token expired, need to re-authenticate
        try await tokenStore.invalidateToken()
        throw NetworkError.unauthorized(description: "Session expired. Please log in again.")
    }
    
    public func invalidateToken() async throws {
        try await tokenStore.invalidateToken()
    }
}
