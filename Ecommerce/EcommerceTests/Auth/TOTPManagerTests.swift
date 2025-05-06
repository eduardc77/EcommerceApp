import Testing
@testable import Ecommerce
@testable import Networking

@Suite("TOTP Manager Tests")
struct TOTPManagerTests {
    
    // MARK: - Basic Tests
    
    @Test("Initial state is correct")
    func initialState() async throws {
        // Given
        let manager = await createManager()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await !manager.sut.isTOTPMFAEnabled)
    }
    
    @Test("Reset clears all state")
    func resetClearsState() async throws {
        // Given
        let manager = await createManager()
        await manager.setTOTPEnabled(true)
        
        // When
        await manager.sut.reset()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await !manager.sut.isTOTPMFAEnabled)
    }
    
    // MARK: - Enable TOTP Tests
    
    @Test("Enable TOTP succeeds")
    func enableTOTPSucceeds() async throws {
        // Given
        let manager = await createManager()
        
        // When
        let setupData = try await manager.sut.enableTOTP()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(setupData.qrCode == "test-qr-code")
        #expect(setupData.secret == "test-secret")
    }
    
    @Test("Enable TOTP fails when already enabled")
    func enableTOTPFailsWhenEnabled() async throws {
        // Given
        let manager = await createManager()
        await manager.setTOTPEnabled(true)
        
        // When/Then
        do {
            _ = try await manager.sut.enableTOTP()
            throw TestError("Expected error to be thrown")
        } catch let error as TOTPError {
            #expect(error == .alreadyEnabled)
        }
        
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error as? TOTPError == .alreadyEnabled)
    }
    
    @Test("Enable TOTP handles network error")
    func enableTOTPHandlesNetworkError() async throws {
        // Given
        let manager = await createManager()
        let networkError = NetworkError.cannotConnectToHost(description: "Network unavailable")
        await manager.mockTOTPService.setEnableError(networkError)
        
        // When/Then
        do {
            _ = try await manager.sut.enableTOTP()
            throw TestError("Expected error to be thrown")
        } catch let error as TOTPError {
            if case .networkError(let wrappedError) = error {
                #expect(wrappedError as? NetworkError != nil)
            } else {
                throw TestError("Expected networkError but got \(error)")
            }
        }
        
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error is TOTPError)
    }
    
    // MARK: - Verify TOTP Tests
    
    @Test("Verify TOTP succeeds and returns recovery codes")
    func verifyTOTPSucceeds() async throws {
        // Given
        let manager = await createManager()
        let code = "123456"
        
        // When
        let recoveryCodes = try await manager.sut.verifyTOTP(code: code)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await manager.sut.isTOTPMFAEnabled)
        #expect(recoveryCodes.count == 2)
        #expect(recoveryCodes[0].code == "AAAA-BBBB")
        #expect(recoveryCodes[1].code == "CCCC-DDDD")
    }
    
    @Test("Verify TOTP handles invalid code")
    func verifyTOTPHandlesInvalidCode() async throws {
        // Given
        let manager = await createManager()
        await manager.mockTOTPService.setVerifyError(TOTPError.invalidCode)
        
        // When/Then
        do {
            _ = try await manager.sut.verifyTOTP(code: "invalid")
            throw TestError("Expected error to be thrown")
        } catch let error as TOTPError {
            #expect(error == .invalidCode)
        }
        
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error as? TOTPError == .invalidCode)
        #expect(await !manager.sut.isTOTPMFAEnabled)
    }
    
    // MARK: - Disable TOTP Tests
    
    @Test("Disable TOTP succeeds")
    func disableTOTPSucceeds() async throws {
        // Given
        let manager = await createManager()
        await manager.setTOTPEnabled(true)
        let password = "password123"
        
        // When
        try await manager.sut.disable(password: password)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error == nil)
        #expect(await !manager.sut.isTOTPMFAEnabled)
        
        // Verify service calls
        #expect(await manager.mockTOTPService.disableTOTPCallCount == 1)
        let receivedPasswords = await manager.mockTOTPService.disableTOTPReceivedPasswords
        #expect(receivedPasswords.count == 1)
        #expect(receivedPasswords[0] == password)
    }
    
    @Test("Disable TOTP fails when not enabled")
    func disableTOTPFailsWhenNotEnabled() async throws {
        // Given
        let manager = await createManager()
        let password = "password123"
        
        // When/Then
        do {
            try await manager.sut.disable(password: password)
            throw TestError("Expected error to be thrown")
        } catch let error as TOTPError {
            #expect(error == .notEnabled)
        }
        
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.error as? TOTPError == .notEnabled)
    }
}

// MARK: - Test Helpers
extension TOTPManagerTests {
    
    actor TestManager {
        let sut: TOTPManager
        let mockTOTPService: MockTOTPService
        
        init() async {
            self.mockTOTPService = MockTOTPService()
            self.sut = await TOTPManager(totpService: mockTOTPService)
        }
        
        @MainActor
        func setTOTPEnabled(_ value: Bool) async {
            sut.isTOTPMFAEnabled = value
            await mockTOTPService.setTOTPEnabled(value)
        }
    }
    
    func createManager() async -> TestManager {
        await TestManager()
    }
}
