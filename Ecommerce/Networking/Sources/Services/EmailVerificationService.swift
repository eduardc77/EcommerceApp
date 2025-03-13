import Foundation

public protocol EmailVerificationServiceProtocol {
    func getStatus() async throws -> EmailVerificationStatusResponse
    func sendCode() async throws -> MessageResponse
    func verify(code: String) async throws -> MessageResponse
    func verifyInitialEmail(email: String, code: String) async throws -> MessageResponse
    func resendVerificationEmail(email: String) async throws -> MessageResponse
    func disableEmailVerification() async throws -> MessageResponse
}

public actor EmailVerificationService: EmailVerificationServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func getStatus() async throws -> EmailVerificationStatusResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.status,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func sendCode() async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.sendCode,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func verify(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.verify(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func verifyInitialEmail(email: String, code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.verifyInitial(email: email, code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func resendVerificationEmail(email: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.resendVerification(email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func disableEmailVerification() async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.disable,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
} 