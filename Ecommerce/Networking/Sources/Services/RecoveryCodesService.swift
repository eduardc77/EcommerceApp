import Foundation

public protocol RecoveryCodesServiceProtocol {
    func generateCodes() async throws -> RecoveryCodesResponse
    func listCodes() async throws -> RecoveryCodesStatusResponse
    func regenerateCodes(password: String) async throws -> RecoveryCodesResponse
    func verifyCode(code: String, stateToken: String) async throws -> AuthResponse
    func getStatus() async throws -> RecoveryMFAStatusResponse
    func getMFAMethods() async throws -> MFAMethodsResponse
}

public actor RecoveryCodesService: RecoveryCodesServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func generateCodes() async throws -> RecoveryCodesResponse {
        try await apiClient.performRequest(
            from: Store.RecoveryCodes.generateRecoveryCodes,
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func listCodes() async throws -> RecoveryCodesStatusResponse {
        try await apiClient.performRequest(
            from: Store.RecoveryCodes.listRecoveryCodes,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func regenerateCodes(password: String) async throws -> RecoveryCodesResponse {
        try await apiClient.performRequest(
            from: Store.RecoveryCodes.regenerateRecoveryCodes(password: password),
            in: environment,
            allowRetry: false,
            requiresAuthorization: true
        )
    }
    
    public func verifyCode(code: String, stateToken: String) async throws -> AuthResponse {
        try await apiClient.performRequest(
            from: Store.RecoveryCodes.verifyRecoveryCode(code: code, stateToken: stateToken),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }

    public func getStatus() async throws -> RecoveryMFAStatusResponse {
        try await apiClient.performRequest(
            from: Store.RecoveryCodes.status,
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
    
    public func getMFAMethods() async throws -> MFAMethodsResponse {
        try await apiClient.performRequest(
            from: Store.Authentication.getMFAMethods(stateToken: nil),
            in: environment,
            allowRetry: true,
            requiresAuthorization: true
        )
    }
}
