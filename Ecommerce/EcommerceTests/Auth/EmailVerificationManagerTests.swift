import Testing
@testable import Ecommerce
@testable import Networking

@Suite("Email Verification Manager Tests")
struct EmailVerificationManagerTests {
    
    // MARK: - Basic Tests
    
    @Test("Initial state is correct")
    func initialState() async throws {
        // Given
        let manager = await createManager()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await !manager.sut.requiresEmailVerification)
        #expect(await !manager.sut.isEmailMFAEnabled)
    }
    
    @Test("Get email MFA status updates state correctly")
    func getEmailMFAStatus() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.getEmailMFAStatus()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await !manager.sut.requiresEmailVerification)
        #expect(await !manager.sut.isEmailMFAEnabled)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.getEmailMFAStatusCallCount == 1)
    }
    
    // MARK: - Email MFA Tests
    
    @Test("Enable email MFA succeeds")
    func enableEmailMFA() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.enableEmailMFA()
        
        // Then
        #expect(await !manager.sut.isLoading)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.enableEmailMFACallCount == 1)
    }
    
    @Test("Verify email MFA succeeds and returns recovery codes")
    func verifyEmailMFA() async throws {
        // Given
        let manager = await createManager()
        let code = "123456"
        let email = "test@example.com"
        
        // When
        let codes = try await manager.sut.verifyEmailMFA(code: code, email: email)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await manager.sut.isEmailMFAEnabled)
        #expect(codes.isEmpty)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.verifyEmailMFACallCount == 1)
        let receivedCodes = await manager.mockEmailVerificationService.verifyEmailMFAReceivedCodes
        #expect(receivedCodes.count == 1)
        #expect(receivedCodes[0].code == code)
        #expect(receivedCodes[0].email == email)
    }
    
    @Test("Disable email MFA succeeds")
    func disableEmailMFA() async throws {
        // Given
        let manager = await createManager()
        let password = "password123"
        
        // When
        try await manager.sut.disableEmailMFA(password: password)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await !manager.sut.isEmailMFAEnabled)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.disableEmailMFACallCount == 1)
        #expect(await manager.mockEmailVerificationService.disableEmailMFAReceivedPasswords == [password])
    }
    
    @Test("Resend email MFA code succeeds")
    func resendEmailMFACode() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.resendEmailMFACode()
        
        // Then
        #expect(await !manager.sut.isLoading)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.resendEmailMFACodeCallCount == 1)
    }
    
    // MARK: - Initial Email Verification Tests
    
    @Test("Skip verification updates state")
    func skipVerification() async throws {
        // Given
        let manager = await createManager()
        
        // When
        await manager.setRequiresEmailVerification(true)
        await manager.sut.skipVerification()
        
        // Then
        #expect(await !manager.sut.requiresEmailVerification)
    }
    
    @Test("Get initial status updates state correctly")
    func getInitialStatus() async throws {
        // Given
        let manager = await createManager()
        
        // When
        try await manager.sut.getInitialStatus()
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await !manager.sut.requiresEmailVerification)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.getInitialStatusCallCount == 1)
    }
    
    @Test("Send initial verification email succeeds")
    func sendInitialVerificationEmail() async throws {
        // Given
        let manager = await createManager()
        let stateToken = "test-state-token"
        let email = "test@example.com"
        
        // When
        try await manager.sut.sendInitialVerificationEmail(stateToken: stateToken, email: email)
        
        // Then
        #expect(await !manager.sut.isLoading)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.sendInitialVerificationEmailCallCount == 1)
        let params = await manager.mockEmailVerificationService.sendInitialVerificationEmailParams
        #expect(params.count == 1)
        #expect(params[0].stateToken == stateToken)
        #expect(params[0].email == email)
    }
    
    @Test("Verify initial email succeeds")
    func verifyInitialEmail() async throws {
        // Given
        let manager = await createManager()
        let code = "123456"
        let stateToken = "test-state-token"
        let email = "test@example.com"
        
        // When
        await manager.setRequiresEmailVerification(true)
        let response = try await manager.sut.verifyInitialEmail(code: code, stateToken: stateToken, email: email)
        
        // Then
        #expect(await !manager.sut.isLoading)
        #expect(await !manager.sut.requiresEmailVerification)
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.verifyInitialEmailCallCount == 1)
        let params = await manager.mockEmailVerificationService.verifyInitialEmailParams
        #expect(params.count == 1)
        #expect(params[0].code == code)
        #expect(params[0].stateToken == stateToken)
        #expect(params[0].email == email)
    }
    
    @Test("Resend verification email succeeds")
    func resendVerificationEmail() async throws {
        // Given
        let manager = await createManager()
        let stateToken = "test-state-token"
        let email = "test@example.com"
        
        // When
        try await manager.sut.resendVerificationEmail(stateToken: stateToken, email: email)
        
        // Then
        #expect(await !manager.sut.isLoading)
        
        // Verify service calls
        #expect(await manager.mockEmailVerificationService.resendInitialVerificationEmailCallCount == 1)
        let params = await manager.mockEmailVerificationService.resendInitialVerificationEmailParams
        #expect(params.count == 1)
        #expect(params[0].stateToken == stateToken)
        #expect(params[0].email == email)
    }
}

// MARK: - Test Helpers
extension EmailVerificationManagerTests {
    
    actor TestManager {
        let sut: EmailVerificationManager
        let mockEmailVerificationService: MockEmailVerificationService
        
        init() async {
            self.mockEmailVerificationService = MockEmailVerificationService()
            self.sut = await EmailVerificationManager(emailVerificationService: mockEmailVerificationService)
        }
        
        @MainActor
        func setRequiresEmailVerification(_ value: Bool) async {
            sut.requiresEmailVerification = value
        }
    }
    
    func createManager() async -> TestManager {
        await TestManager()
    }
} 
