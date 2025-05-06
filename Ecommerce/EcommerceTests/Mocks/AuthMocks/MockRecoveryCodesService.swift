@testable import Networking

actor MockRecoveryCodesService: RecoveryCodesServiceProtocol {
    // Test configuration
    private var generateError: Error?
    private var verifyError: Error?
    private var listError: Error?
    private var statusError: Error?
    
    // Call tracking
    private(set) var generateCalls: Int = 0
    private(set) var regenerateCalls: [String] = [] // passwords
    private(set) var verifyCalls: [(code: String, stateToken: String)] = []
    private(set) var listCalls: Int = 0
    private(set) var statusCalls: Int = 0
    
    // Test setup helpers
    func setGenerateError(_ error: Error) {
        self.generateError = error
    }
    
    func setVerifyError(_ error: Error) {
        self.verifyError = error
    }
    
    func setListError(_ error: Error) {
        self.listError = error
    }
    
    func setStatusError(_ error: Error) {
        self.statusError = error
    }
    
    func reset() {
        generateError = nil
        verifyError = nil
        listError = nil
        statusError = nil
        generateCalls = 0
        regenerateCalls = []
        verifyCalls = []
        listCalls = 0
        statusCalls = 0
    }
    
    // Protocol implementation
    func generateCodes() async throws -> RecoveryCodesResponse {
        generateCalls += 1
        if let error = generateError { throw error }
        return RecoveryCodesResponse(
            codes: ["code1", "code2"],
            message: "Codes generated",
            expiresAt: "2024-01-01T00:00:00Z"
        )
    }
    
    func regenerateCodes(password: String) async throws -> RecoveryCodesResponse {
        regenerateCalls.append(password)
        if let error = generateError { throw error }
        return RecoveryCodesResponse(
            codes: ["newcode1", "newcode2"],
            message: "Codes regenerated",
            expiresAt: "2024-01-01T00:00:00Z"
        )
    }
    
    func verifyCode(code: String, stateToken: String) async throws -> AuthResponse {
        verifyCalls.append((code: code, stateToken: stateToken))
        if let error = verifyError { throw error }
        return AuthResponse(status: AuthResponse.STATUS_SUCCESS)
    }
    
    func listCodes() async throws -> RecoveryCodesStatusResponse {
        listCalls += 1
        if let error = listError { throw error }
        return RecoveryCodesStatusResponse(
            totalCodes: 2,
            usedCodes: 0,
            remainingCodes: 2,
            expiredCodes: 0,
            validCodes: 2,
            shouldRegenerate: false,
            nextExpirationDate: "2024-01-01T00:00:00Z"
        )
    }
    
    func getStatus() async throws -> RecoveryMFAStatusResponse {
        statusCalls += 1
        if let error = statusError { throw error }
        return RecoveryMFAStatusResponse(enabled: true, hasValidCodes: true)
    }
    
    func getMFAMethods() async throws -> MFAMethodsResponse {
        MFAMethodsResponse()
    }
}
