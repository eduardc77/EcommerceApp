import Foundation

public protocol TOTPServiceProtocol {
    func setup() async throws -> TOTPSetupResponse
    func verify(code: String) async throws -> MessageResponse
    func enable(code: String) async throws -> MessageResponse
    func disable(code: String) async throws -> MessageResponse
    func getStatus() async throws -> TOTPStatusResponse
}

public actor TOTPService: TOTPServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func setup() async throws -> TOTPSetupResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.setup,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func verify(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.verify(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func enable(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.enable(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func disable(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.disable(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func getStatus() async throws -> TOTPStatusResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.status,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
} 