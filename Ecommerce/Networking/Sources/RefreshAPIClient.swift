import Foundation
import OSLog

public protocol RefreshAPIClientProtocol: Sendable {
    func refreshToken(_ token: String) async throws -> OAuthToken
}

public actor RefreshAPIClient: RefreshAPIClientProtocol {
    private let environment: Store.Environment
    private let urlSession: URLSession
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Networking", category: "RefreshAPIClient")
    
    public init(
        environment: Store.Environment = .develop,
        urlSession: URLSession = NetworkConfiguration.default
    ) {
        self.environment = environment
        self.urlSession = urlSession
    }
    
    public func refreshToken(_ refreshToken: String) async throws -> OAuthToken {
        do {
            let request = try RequestBuilder.buildRequest(
                for: Store.Authentication.refreshToken(refreshToken),
                in: environment
            )
            
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse(description: "Invalid response")
            }
            
            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                
                guard let accessToken = authResponse.accessToken,
                      let refreshToken = authResponse.refreshToken,
                      let expiresIn = authResponse.expiresIn,
                      let expiresAt = authResponse.expiresAt else {
                    throw NetworkError.invalidResponse(description: "Missing required token fields")
                }
                
                return Token(
                    accessToken: accessToken,
                    refreshToken: refreshToken,
                    tokenType: authResponse.tokenType,
                    expiresIn: expiresIn,
                    expiresAt: expiresAt
                )
            }
            
            throw NetworkError.unauthorized(description: "Failed to refresh token")
        } catch {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            throw error
        }
    }
} 
