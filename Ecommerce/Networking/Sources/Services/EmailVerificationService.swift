import Foundation

public protocol EmailVerificationServiceProtocol: Actor {
    @Sendable func getInitialStatus() async throws -> EmailVerificationStatusResponse
    @Sendable func getEmailMFAStatus() async throws -> EmailVerificationStatusResponse
    @Sendable func sendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse
    @Sendable func resendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse
    @Sendable func verifyInitialEmail(code: String, stateToken: String, email: String) async throws -> AuthResponse
    @Sendable func enableEmailMFA() async throws -> MessageResponse
    @Sendable func verifyEmailMFA(code: String, email: String) async throws -> MFAVerifyResponse
    @Sendable func disableEmailMFA(password: String) async throws -> MessageResponse
    @Sendable func resendEmailMFACode() async throws -> MessageResponse
}

public actor EmailVerificationService: EmailVerificationServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }

    public func getInitialStatus() async throws -> EmailVerificationStatusResponse {
        try await apiClient.performRequest(
            from: Store.Authentication.getInitialEmailVerificationStatus,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }

    public func getEmailMFAStatus() async throws -> EmailVerificationStatusResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.getEmailMFAStatus,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func sendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.Authentication.sendInitialVerificationEmail(stateToken: stateToken, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func resendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.Authentication.resendInitialVerificationEmail(stateToken: stateToken, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }

    public func verifyInitialEmail(code: String, stateToken: String, email: String) async throws -> AuthResponse {
        try await apiClient.performRequest(
            from: Store.Authentication.verifyInitialEmail(code: code, stateToken: stateToken, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }

    public func enableEmailMFA() async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.enableEmailMFA,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }

    public func verifyEmailMFA(code: String, email: String) async throws -> MFAVerifyResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.verifyEmailMFA(code: code, email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func disableEmailMFA(password: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.disableEmailMFA(password: password),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func resendEmailMFACode() async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.resendEmailMFACode,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
}

struct EmailVerifyRequest: Codable {
    let email: String
    let code: String
}

struct InitialEmailVerifyRequest: Codable {
    let code: String
    let stateToken: String
}

struct EmailSignInVerifyRequest: Codable {
    let stateToken: String
    let code: String
}
