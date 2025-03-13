import Foundation

public protocol EmailVerificationServiceProtocol {
    func verifyInitialEmail(code: String) async throws -> MessageResponse
    func resendVerification(email: String) async throws -> MessageResponse
    func sendVerificationCode() async throws -> MessageResponse
    func verifyEmailCode(code: String) async throws -> MessageResponse
    func disable(code: String) async throws -> MessageResponse
    func getStatus() async throws -> EmailVerificationStatusResponse
}

public actor EmailVerificationService: EmailVerificationServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func verifyInitialEmail(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.verifyInitial(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func resendVerification(email: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.resend(email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func sendVerificationCode() async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.sendCode,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func verifyEmailCode(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.verify(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func disable(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.disable(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func getStatus() async throws -> EmailVerificationStatusResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.status,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
} 