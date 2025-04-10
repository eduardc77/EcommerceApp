import Foundation
import Testing
@testable import Networking

final class TOTPServiceTests {
    // MARK: - Test Properties
    let mockAPIClient: MockAPIClient
    var sut: TOTPService!
    
    // MARK: - Init
    init() {
        self.mockAPIClient = MockAPIClient()
    }
    
    // MARK: - Setup
    func setUp() async {
        sut = TOTPService(apiClient: mockAPIClient)
    }
    
    // MARK: - Enable TOTP Tests
    @Test("Enable TOTP returns setup data with QR code URL and secret")
    func testEnableTOTPSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = TOTPSetupResponse(
            secret: "JBSWY3DPEHPK3PXP",
            qrCodeUrl: "otpauth://totp/Example:alice@google.com?secret=JBSWY3DPEHPK3PXP&issuer=Example"
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.enable)
        
        // When
        let response = try await sut.enableTOTP()
        
        // Then
        #expect(response.secret == expectedResponse.secret)
        #expect(response.qrCodeUrl == expectedResponse.qrCodeUrl)
    }
    
    // MARK: - Verify TOTP Tests
    @Test("Verify TOTP with valid code returns success and recovery codes")
    func testVerifyTOTPSuccess() async throws {
        await setUp()
        
        // Given
        let code = "123456"
        let expectedResponse = MFAVerifyResponse(
            message: "TOTP verified successfully",
            success: true,
            recoveryCodes: ["11111-22222", "33333-44444", "55555-66666"]
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.verify(code: code))
        
        // When
        let response = try await sut.verifyTOTP(code: code)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
        #expect(response.recoveryCodes?.count == 3)
    }
    
    @Test("Verify TOTP with invalid code returns failure")
    func testVerifyTOTPFailure() async throws {
        await setUp()
        
        // Given
        let code = "000000"
        let expectedResponse = MFAVerifyResponse(
            message: "Invalid TOTP code",
            success: false
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.verify(code: code))
        
        // When
        let response = try await sut.verifyTOTP(code: code)
        
        // Then
        #expect(response.success == false)
        #expect(response.message == expectedResponse.message)
        #expect(response.recoveryCodes == nil)
    }
    
    // MARK: - Disable TOTP Tests
    @Test("Disable TOTP with valid password returns success")
    func testDisableTOTPSuccess() async throws {
        await setUp()
        
        // Given
        let password = "password123"
        let expectedResponse = MessageResponse(
            message: "TOTP MFA disabled successfully",
            success: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.disable(password: password))
        
        // When
        let response = try await sut.disableTOTP(password: password)
        
        // Then
        #expect(response.success == true)
        #expect(response.message == expectedResponse.message)
    }
    
    @Test("Disable TOTP with invalid password returns failure")
    func testDisableTOTPFailure() async throws {
        await setUp()
        
        // Given
        let password = "wrongpassword"
        let expectedResponse = MessageResponse(
            message: "Invalid password",
            success: false
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.disable(password: password))
        
        // When
        let response = try await sut.disableTOTP(password: password)
        
        // Then
        #expect(response.success == false)
        #expect(response.message == expectedResponse.message)
    }
    
    // MARK: - TOTP Status Tests
    @Test("Get TOTP status when enabled returns true")
    func testGetTOTPStatusEnabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = TOTPStatusResponse(totpMFAEnabled: true)
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.status)
        
        // When
        let response = try await sut.getTOTPStatus()
        
        // Then
        #expect(response.totpMfaEnabled == true)
    }
    
    @Test("Get TOTP status when disabled returns false")
    func testGetTOTPStatusDisabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = TOTPStatusResponse(totpMFAEnabled: false)
        await mockAPIClient.mockResponse(expectedResponse, for: Store.TOTP.status)
        
        // When
        let response = try await sut.getTOTPStatus()
        
        // Then
        #expect(response.totpMfaEnabled == false)
    }
} 