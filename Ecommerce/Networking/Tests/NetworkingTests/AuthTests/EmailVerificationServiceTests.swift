import Foundation
import Testing
@testable import Networking

final class EmailVerificationServiceTests {
    // MARK: - Test Properties
    let mockAPIClient: MockAPIClient
    var sut: EmailVerificationService!
    
    // MARK: - Init
    init() {
        self.mockAPIClient = MockAPIClient()
    }
    
    // MARK: - Setup
    func setUp() async {
        sut = EmailVerificationService(apiClient: mockAPIClient)
    }
    
    // MARK: - Status Tests
    @Test("Get initial verification status returns correct state")
    func testGetInitialStatusSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = EmailVerificationStatusResponse(
            emailMFAEnabled: false,
            emailVerified: false
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.getInitialEmailVerificationStatus)
        
        // When
        let response = try await sut.getInitialStatus()
        
        // Then
        #expect(response.emailMfaEnabled == false)
        #expect(response.emailVerified == false)
    }
    
    @Test("Get email MFA status returns enabled state")
    func testGetEmailMFAStatusEnabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = EmailVerificationStatusResponse(
            emailMFAEnabled: true,
            emailVerified: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.EmailVerification.getEmailMFAStatus)
        
        // When
        let response = try await sut.getEmailMFAStatus()
        
        // Then
        #expect(response.emailMfaEnabled == true)
        #expect(response.emailVerified == true)
    }
    
    // MARK: - Initial Verification Tests
    @Test("Send initial verification email returns success")
    func testSendInitialVerificationEmailSuccess() async throws {
        await setUp()
        
        // Given
        let stateToken = "verification-state-token"
        let email = "test@example.com"
        let expectedResponse = MessageResponse(
            message: "Verification email sent successfully",
            success: true
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.Authentication.sendInitialVerificationEmail(stateToken: stateToken, email: email)
        )
        
        // When
        let response = try await sut.sendInitialVerificationEmail(stateToken: stateToken, email: email)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
    
    @Test("Verify initial email returns auth response with tokens")
    func testVerifyInitialEmailSuccess() async throws {
        await setUp()
        
        // Given
        let code = "123456"
        let stateToken = "verification-state-token"
        let email = "test@example.com"
        let expectedResponse = AuthResponse(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.mockUser(),
            status: AuthResponse.STATUS_SUCCESS
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.Authentication.verifyInitialEmail(code: code, stateToken: stateToken, email: email)
        )
        
        // When
        let response = try await sut.verifyInitialEmail(code: code, stateToken: stateToken, email: email)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        #expect(response.accessToken == expectedResponse.accessToken)
        #expect(response.refreshToken == expectedResponse.refreshToken)
    }
    
    // MARK: - Email MFA Tests
    @Test("Enable email MFA returns success")
    func testEnableEmailMFASuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = MessageResponse(
            message: "Email MFA enabled successfully",
            success: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.EmailVerification.enableEmailMFA)
        
        // When
        let response = try await sut.enableEmailMFA()
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
    
    @Test("Verify email MFA returns success with recovery codes")
    func testVerifyEmailMFASuccess() async throws {
        await setUp()
        
        // Given
        let code = "123456"
        let email = "test@example.com"
        let expectedResponse = MFAVerifyResponse(
            message: "Email MFA verified successfully",
            success: true,
            recoveryCodes: ["11111-22222", "33333-44444", "55555-66666"]
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.EmailVerification.verifyEmailMFA(code: code, email: email)
        )
        
        // When
        let response = try await sut.verifyEmailMFA(code: code, email: email)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
        #expect(response.recoveryCodes?.count == 3)
    }
    
    @Test("Disable email MFA with valid password returns success")
    func testDisableEmailMFASuccess() async throws {
        await setUp()
        
        // Given
        let password = "password123"
        let expectedResponse = MessageResponse(
            message: "Email MFA disabled successfully",
            success: true
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.EmailVerification.disableEmailMFA(password: password)
        )
        
        // When
        let response = try await sut.disableEmailMFA(password: password)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
    
    @Test("Resend email MFA code returns success")
    func testResendEmailMFACodeSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = MessageResponse(
            message: "MFA code resent successfully",
            success: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.EmailVerification.resendEmailMFACode)
        
        // When
        let response = try await sut.resendEmailMFACode()
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
    
    @Test("Resend initial verification email returns success")
    func testResendInitialVerificationEmailSuccess() async throws {
        await setUp()
        
        // Given
        let stateToken = "verification-state-token"
        let email = "test@example.com"
        let expectedResponse = MessageResponse(
            message: "Verification email resent successfully",
            success: true
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.Authentication.resendInitialVerificationEmail(stateToken: stateToken, email: email)
        )
        
        // When
        let response = try await sut.resendInitialVerificationEmail(stateToken: stateToken, email: email)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
} 