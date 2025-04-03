import Foundation

public protocol TOTPServiceProtocol {
    func verifyTOTP(code: String) async throws -> MessageResponse
    func enableTOTP() async throws -> TOTPSetupResponse
    func disableTOTP(password: String) async throws -> MessageResponse
    func getTOTPStatus() async throws -> TOTPStatusResponse
}

public actor TOTPService: TOTPServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }

    public func enableTOTP() async throws -> TOTPSetupResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.enable,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }


    public func verifyTOTP(code: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.verify(code: code),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }

    public func disableTOTP(password: String) async throws -> MessageResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.disable(password: password),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func getTOTPStatus() async throws -> TOTPStatusResponse {
        try await apiClient.performRequest(
            from: Store.TOTP.status,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
} 
