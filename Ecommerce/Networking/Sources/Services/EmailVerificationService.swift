import Foundation

public protocol EmailVerificationServiceProtocol {
    func getInitialStatus() async throws -> EmailVerificationStatusResponse
    func get2FAStatus() async throws -> EmailVerificationStatusResponse
    func verifyInitialEmail(email: String, code: String) async throws -> MessageResponse
    func resendVerificationEmail(email: String) async throws -> MessageResponse
    func setup2FA() async throws -> MessageResponse
    func verify2FA(code: String) async throws -> MessageResponse
    func disable2FA(code: String) async throws -> MessageResponse
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
            from: Store.EmailVerification.initialStatus,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }

    public func get2FAStatus() async throws -> EmailVerificationStatusResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.get2FAStatus,
            in: environment,
            allowRetry: true,
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
            from: Store.EmailVerification.resend(email: email),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }

    public func setup2FA() async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.setup2FA,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }

    public func verify2FA(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.verify2FA(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }

    public func disable2FA(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.EmailVerification.disable2FA(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
}

struct EmailVerifyRequest: Codable {
    let code: String
}

struct ResendVerificationRequest: Codable {
    let email: String
}

struct EmailLoginVerifyRequest: Codable {
    let tempToken: String
    let code: String
}
