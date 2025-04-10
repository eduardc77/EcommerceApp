import Foundation
@testable import Networking

/// A mock API client for testing that allows setting predefined responses for endpoints
public final actor MockAPIClient: APIClient {
    /// Thread-safe type-erasing wrapper for storing mock responses
    private struct AnyResponse: Sendable {
        private let value: any (Decodable & Sendable)
        
        init<T: Decodable & Sendable>(_ value: T) {
            self.value = value
        }
        
        func get<T: Decodable & Sendable>() -> T? {
            return value as? T
        }
    }
    
    /// Storage for mock responses keyed by endpoint path
    private var responses: [String: AnyResponse] = [:]
    
    public init() {}
    
    /// Stores a mock response for a specific endpoint
    public func mockResponse<T: Codable & Sendable>(_ response: T, for endpoint: APIEndpoint) {
        responses[endpoint.path] = AnyResponse(response)
    }
    
    /// Stores an empty response for a specific endpoint
    public func mockEmptyResponse(for endpoint: APIEndpoint) {
        responses[endpoint.path] = AnyResponse(EmptyResponse())
    }
    
    /// Clears all stored mock responses
    public func reset() {
        responses.removeAll()
    }
    
    /// Implementation of APIClient protocol method
    public nonisolated func performRequest<T: Decodable & Sendable>(
        from endpoint: APIEndpoint,
        in environment: APIEnvironment,
        allowRetry: Bool,
        requiresAuthorization: Bool
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                let path = endpoint.path
                
                guard let anyResponse = await responses[path] else {
                    continuation.resume(throwing: NetworkError.invalidResponse(
                        description: "No mock response set for endpoint: \(path)"
                    ))
                    return
                }
                
                guard let response: T = anyResponse.get() else {
                    continuation.resume(throwing: NetworkError.invalidResponse(
                        description: "Invalid response type for endpoint: \(path). Expected \(T.self)"
                    ))
                    return
                }
                
                continuation.resume(returning: response)
            }
        }
    }
}
