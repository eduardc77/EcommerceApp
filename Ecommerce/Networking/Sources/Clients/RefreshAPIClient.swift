import Foundation
import OSLog

public protocol RefreshAPIClientProtocol: Sendable {
    func refreshToken(_ token: String) async throws -> OAuthToken
}

public actor RefreshAPIClient: RefreshAPIClientProtocol {
    private let environment: Store.Environment
    private let urlSession: URLSessionProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Networking", category: "RefreshAPIClient")
    
    public init(
        environment: Store.Environment = .develop,
        urlSession: URLSessionProtocol = NetworkConfiguration.default
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
                return Token(
                    accessToken: authResponse.accessToken,
                    refreshToken: authResponse.refreshToken,
                    tokenType: authResponse.tokenType,
                    expiresIn: authResponse.expiresIn,
                    expiresAt: authResponse.expiresAt
                )
            }
            
            throw NetworkError.unauthorized(description: "Failed to refresh token")
        } catch {
            logger.error("Token refresh failed: \(error.localizedDescription)")
            throw error
        }
    }
} 
