import Foundation
import OSLog

public protocol APIClient: Sendable {
    func performRequest<T: Decodable & Sendable>(from endpoint: APIEndpoint, in environment: APIEnvironment, allowRetry: Bool, requiresAuthorization: Bool) async throws -> T
}

public final class DefaultAPIClient: APIClient {
    private let networkManager: NetworkManager
    private let responseHandler: ResponseHandler
    
    public init(authorizationManager: AuthorizationManagerProtocol) {
        self.networkManager = NetworkManager(authorizationManager: authorizationManager)
        self.responseHandler = ResponseHandler()
    }
    
    public func performRequest<T: Decodable & Sendable>(
        from endpoint: APIEndpoint,
        in environment: APIEnvironment,
        allowRetry: Bool = true,
        requiresAuthorization: Bool = true
    ) async throws -> T {
        let urlRequest = try endpoint.urlRequest(environment: environment)
        Logger.logRequest(urlRequest)
        return try await executeRequest(
            urlRequest,
            allowRetry: allowRetry,
            requiresAuthorization: requiresAuthorization
        )
    }
    
    public func performMultipartRequest<T: Decodable & Sendable>(from endpoint: APIEndpoint, in environment: APIEnvironment, multipartFormData: MultipartFormData, allowRetry: Bool = true, requiresAuthorization: Bool = true) async throws -> T {
        let urlRequest = try endpoint.multipartURLRequest(environment: environment, multipartFormData: multipartFormData)
        Logger.logRequest(urlRequest)
        return try await executeRequest(urlRequest, allowRetry: allowRetry, requiresAuthorization: requiresAuthorization)
    }
    
    private func executeRequest<T: Decodable & Sendable>(
        _ urlRequest: URLRequest, 
        allowRetry: Bool, 
        requiresAuthorization: Bool
    ) async throws -> T {
        do {
            let (data, response) = try await networkManager.performRequest(
                with: urlRequest, 
                requiresAuthorization: requiresAuthorization
            )
            Logger.logResponse(response, data: data)
            return try await responseHandler.decode(data)
        } catch {
            Logger.networking.error("Request failed: \(error.localizedDescription)")
            throw error
        }
    }
}
