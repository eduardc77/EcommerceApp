import Testing
@testable import Ecommerce
@testable import Networking

@Suite("Recovery Codes Manager Tests")
struct RecoveryCodesManagerTests {
    
    // MARK: - Basic Tests
    
    @Test("Initial state is correct")
    func initialState() async throws {
        // Given
        let manager = await createManager()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await manager.sut.codes.isEmpty)
        #expect(await manager.sut.message.isEmpty)
        #expect(await manager.sut.expiresAt.isEmpty)
        #expect(await manager.sut.status == nil)
        #expect(await !manager.sut.shouldRegenerate)
    }
    
    @Test("Get status updates state correctly")
    func getStatusSuccess() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.getStatus()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await manager.sut.status?.enabled == true)
        #expect(await manager.sut.status?.hasValidCodes == true)
        #expect(await !manager.sut.shouldRegenerate)
    }
    
    @Test("Generate codes succeeds")
    func generateCodesSuccess() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.generateCodes()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await !manager.sut.codes.isEmpty)
        #expect(await manager.sut.message == "Codes generated")
        #expect(await manager.sut.expiresAt == "2024-01-01T00:00:00Z")
        #expect(await manager.sut.status?.hasValidCodes == true)
        #expect(await !manager.sut.shouldRegenerate)
    }
    
    @Test("Regenerate codes with password succeeds")
    func regenerateCodesSuccess() async throws {
        // Given
        let manager = await createManager()
        let password = "password123"
        
        // When
        try await manager.sut.generateCodes(password: password)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await !manager.sut.codes.isEmpty)
        #expect(await manager.sut.message == "Codes regenerated")
        #expect(await manager.sut.expiresAt == "2024-01-01T00:00:00Z")
        #expect(await manager.sut.status?.hasValidCodes == true)
        #expect(await !manager.sut.shouldRegenerate)
    }
    
    @Test("Verify code during sign in succeeds")
    func verifyCodeSuccess() async throws {
        // Given
        let manager = await createManager()
        let code = "123456"
        let stateToken = "test-state-token"
        
        // When
        let response = try await manager.sut.verifyCode(code: code, stateToken: stateToken)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
    }
    
    @Test("Get codes list succeeds")
    func getCodesSuccess() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.getCodes()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await !manager.sut.codes.isEmpty)
        #expect(await !manager.sut.shouldRegenerate)
        #expect(await manager.sut.status?.hasValidCodes == true)
    }
    
    // MARK: - Error Cases
    
    @Test("Generate codes handles network error")
    func generateCodesNetworkError() async throws {
        // Given
        let manager = await createManager()
        await manager.mockRecoveryCodesService.setGenerateError(
            NetworkError.cannotConnectToHost(description: "Network unavailable")
        )
        
        // When/Then
        do {
            try await manager.sut.generateCodes()
            throw TestError("Expected error to be thrown")
        } catch let error as RecoveryCodesError {
            if case .networkError(let networkError) = error {
                #expect(networkError as? NetworkError != nil)
            } else {
                throw TestError("Expected networkError but got \(error)")
            }
        }
        
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error is RecoveryCodesError)
    }
    
    @Test("Verify code handles invalid code error")
    func verifyCodeInvalidError() async throws {
        // Given
        let manager = await createManager()
        await manager.mockRecoveryCodesService.setVerifyError(
            NetworkError.badRequest(description: "Invalid code")
        )
        
        // When/Then
        do {
            let response = try await manager.sut.verifyCode(code: "invalid", stateToken: "test-token")
            #expect(response.status == AuthResponse.STATUS_MFA_RECOVERY_CODE_REQUIRED)
            throw TestError("Expected error to be thrown")
        } catch let error as RecoveryCodesError {
            if case .networkError(let networkError) = error {
                #expect(networkError as? NetworkError != nil)
            } else {
                throw TestError("Expected networkError but got \(error)")
            }
        }
        
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error is RecoveryCodesError)
    }
}

// MARK: - Test Helpers
extension RecoveryCodesManagerTests {
    
    actor TestManager {
        let sut: RecoveryCodesManager
        let mockRecoveryCodesService: MockRecoveryCodesService
        
        init() async {
            self.mockRecoveryCodesService = MockRecoveryCodesService()
            self.sut = await RecoveryCodesManager(recoveryCodesService: mockRecoveryCodesService)
        }
    }
    
    func createManager() async -> TestManager {
        await TestManager()
    }
}
