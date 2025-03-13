import Foundation

public protocol HealthServiceProtocol {
    func checkHealth() async throws -> HealthCheckResponse
}

public actor HealthService: HealthServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func checkHealth() async throws -> HealthCheckResponse {
        try await apiClient.performRequest(
            from: Store.Health.check,
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
} 