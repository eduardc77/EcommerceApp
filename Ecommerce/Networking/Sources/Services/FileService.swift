import Foundation

public protocol FileServiceProtocol {
    func upload(file: FileData, filename: String?) async throws -> MessageResponse
    func download(filename: String) async throws -> Data
}

public actor FileService: FileServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func upload(file: FileData, filename: String?) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.File.upload(file: file, filename: filename),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func download(filename: String) async throws -> Data {
        try await apiClient.performRequest(
            from: Store.File.download(filename: filename),
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
} 