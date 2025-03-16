import Foundation
import OSLog

public protocol AuthorizationManagerProtocol: Actor {
    func getValidToken() async throws -> OAuthToken
    func invalidateToken() async throws
    func storeToken(_ token: OAuthToken) async
}

public actor AuthorizationManager: AuthorizationManagerProtocol {
    private let refreshClient: RefreshAPIClientProtocol
    private let tokenStore: TokenStoreProtocol
    private var refreshTask: Task<OAuthToken, Error>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Networking", category: "AuthorizationManager")
    
    public init(
        refreshClient: RefreshAPIClientProtocol,
        tokenStore: TokenStoreProtocol
    ) {
        self.refreshClient = refreshClient
        self.tokenStore = tokenStore
    }
    
    public func getValidToken() async throws -> OAuthToken {
        if let refreshTask = refreshTask {
            // A refresh task is in progress
            logger.debug("Using existing refresh task")
            return try await refreshTask.value
        }
        
        guard let token = try await tokenStore.getToken() else {
            logger.error("No token found in store")
            throw NetworkError.missingToken(description: "No token found")
        }
        
        if token.isAccessTokenValid {
            logger.debug("Using existing valid token")
            return token
        }
        
        return try await refreshToken()
    }
    
    private func refreshToken() async throws -> OAuthToken {
        if let refreshTask = refreshTask {
            // A refresh task is in progress
            logger.debug("Using existing refresh task")
            return try await refreshTask.value
        }
        
        guard let token = try await tokenStore.getToken(),
              !token.refreshToken.isEmpty else {
            logger.error("No refresh token available")
            throw NetworkError.missingToken(description: "No refresh token found")
        }
        
        let refreshTask = Task { () throws -> OAuthToken in
            defer { self.refreshTask = nil }
            
            logger.debug("Starting token refresh")
            let newToken = try await refreshClient.refreshToken(token.refreshToken)
            try await tokenStore.setToken(newToken)
            logger.debug("Token refresh completed successfully")
            return newToken
        }
        
        self.refreshTask = refreshTask
        return try await refreshTask.value
    }
    
    public func invalidateToken() async throws {
        logger.debug("Invalidating token")
        refreshTask?.cancel()
        refreshTask = nil
        try await tokenStore.invalidateToken()
    }
    
    public func storeToken(_ token: OAuthToken) async {
        logger.debug("Storing new token")
        try? await tokenStore.setToken(token)
    }
    
    // For testing purposes only
    #if DEBUG
    func hasActiveRefreshTask() -> Bool {
        refreshTask != nil
    }
    #endif
}
