import Foundation
import OSLog

actor AuthorizationHandler {
    private let authorizationManager: AuthorizationManagerProtocol
    private let urlSession: URLSessionProtocol
    private var isRefreshing = false
    
    init(
        authorizationManager: AuthorizationManagerProtocol,
        urlSession: URLSessionProtocol
    ) {
        self.authorizationManager = authorizationManager
        self.urlSession = urlSession
    }
    
    func authorizeRequest(_ request: URLRequest) async throws -> URLRequest {
        guard request.url != nil else {
            throw NetworkError.invalidResponse(description: "Invalid URL in request.")
        }
        
        let token = try await authorizationManager.getValidToken()
        return RequestBuilder.addAuthorization(to: request, token: token.accessToken)
    }
    
    func handleTokenRefresh(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard !isRefreshing else {
            throw NetworkError.unauthorized(description: "Token refresh already in progress")
        }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            _ = try await authorizationManager.getValidToken()
            let authorizedRequest = try await authorizeRequest(request)
            let (data, response) = try await urlSession.data(for: authorizedRequest)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse(description: "Invalid response")
            }
            
            if httpResponse.statusCode == 401 {
                try await authorizationManager.invalidateToken()
                throw NetworkError.unauthorized(description: "Session expired. Please log in again.")
            }
            
            return (data, httpResponse)
        } catch {
            try? await authorizationManager.invalidateToken()
            throw NetworkError.unauthorized(description: "Failed to refresh session: \(error.localizedDescription)")
        }
    }
} 