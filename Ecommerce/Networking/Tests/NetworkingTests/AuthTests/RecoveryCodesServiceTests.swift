import Foundation
import Testing
@testable import Networking

final class RecoveryCodesServiceTests {
    // MARK: - Test Properties
    let mockAPIClient: MockAPIClient
    var sut: RecoveryCodesService!
    
    // MARK: - Init
    init() {
        self.mockAPIClient = MockAPIClient()
    }
    
    // MARK: - Setup
    func setUp() async {
        sut = RecoveryCodesService(apiClient: mockAPIClient)
    }
    
    // MARK: - Generate Codes Tests
    @Test("Generate recovery codes returns new codes with expiration")
    func testGenerateCodesSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = RecoveryCodesResponse(
            codes: ["11111-22222", "33333-44444", "55555-66666"],
            message: "Recovery codes generated successfully",
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 24 * 3600)) // 30 days
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.RecoveryCodes.generateRecoveryCodes)
        
        // When
        let response = try await sut.generateCodes()
        
        // Then
        #expect(response.codes.count == 3)
        #expect(response.message == expectedResponse.message)
        #expect(response.expiresAt == expectedResponse.expiresAt)
    }
    
    // MARK: - List Codes Tests
    @Test("List recovery codes returns current status")
    func testListCodesSuccess() async throws {
        await setUp()
        
        // Given
        let expectedResponse = RecoveryCodesStatusResponse(
            totalCodes: 10,
            usedCodes: 2,
            remainingCodes: 8,
            expiredCodes: 0,
            validCodes: 8,
            shouldRegenerate: false,
            nextExpirationDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 24 * 3600))
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.RecoveryCodes.listRecoveryCodes)
        
        // When
        let response = try await sut.listCodes()
        
        // Then
        #expect(response.totalCodes == 10)
        #expect(response.usedCodes == 2)
        #expect(response.remainingCodes == 8)
        #expect(response.expiredCodes == 0)
        #expect(response.validCodes == 8)
        #expect(response.shouldRegenerate == false)
        #expect(response.nextExpirationDate == expectedResponse.nextExpirationDate)
    }
    
    @Test("List codes when regeneration needed returns correct status")
    func testListCodesNeedsRegeneration() async throws {
        await setUp()
        
        // Given
        let expectedResponse = RecoveryCodesStatusResponse(
            totalCodes: 10,
            usedCodes: 8,
            remainingCodes: 2,
            expiredCodes: 0,
            validCodes: 2,
            shouldRegenerate: true,
            nextExpirationDate: ISO8601DateFormatter().string(from: Date().addingTimeInterval(24 * 3600))
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.RecoveryCodes.listRecoveryCodes)
        
        // When
        let response = try await sut.listCodes()
        
        // Then
        #expect(response.shouldRegenerate == true)
        #expect(response.remainingCodes == 2)
        #expect(response.validCodes == 2)
    }
    
    // MARK: - Regenerate Codes Tests
    @Test("Regenerate codes with valid password returns new codes")
    func testRegenerateCodesSuccess() async throws {
        await setUp()
        
        // Given
        let password = "password123"
        let expectedResponse = RecoveryCodesResponse(
            codes: ["aaaaa-bbbbb", "ccccc-ddddd", "eeeee-fffff"],
            message: "Recovery codes regenerated successfully",
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(30 * 24 * 3600))
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.RecoveryCodes.regenerateRecoveryCodes(password: password)
        )
        
        // When
        let response = try await sut.regenerateCodes(password: password)
        
        // Then
        #expect(response.codes.count == 3)
        #expect(response.message == expectedResponse.message)
        #expect(response.expiresAt == expectedResponse.expiresAt)
    }
    
    // MARK: - Verify Code Tests
    @Test("Verify recovery code returns auth response with tokens")
    func testVerifyCodeSuccess() async throws {
        await setUp()
        
        // Given
        let code = "11111-22222"
        let stateToken = "state-token"
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
            for: Store.RecoveryCodes.verifyRecoveryCode(code: code, stateToken: stateToken)
        )
        
        // When
        let response = try await sut.verifyCode(code: code, stateToken: stateToken)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        #expect(response.accessToken == expectedResponse.accessToken)
        #expect(response.refreshToken == expectedResponse.refreshToken)
    }
    
    // MARK: - Status Tests
    @Test("Get recovery MFA status returns enabled state")
    func testGetStatusEnabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = RecoveryMFAStatusResponse(
            enabled: true,
            hasValidCodes: true
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.RecoveryCodes.status)
        
        // When
        let response = try await sut.getStatus()
        
        // Then
        #expect(response.enabled == true)
        #expect(response.hasValidCodes == true)
    }
    
    @Test("Get recovery MFA status when disabled returns correct state")
    func testGetStatusDisabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = RecoveryMFAStatusResponse(
            enabled: false,
            hasValidCodes: false
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.RecoveryCodes.status)
        
        // When
        let response = try await sut.getStatus()
        
        // Then
        #expect(response.enabled == false)
        #expect(response.hasValidCodes == false)
    }
    
    // MARK: - MFA Methods Tests
    @Test("Get MFA methods returns available methods when none enabled")
    func testGetMFAMethodsNoneEnabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = MFAMethodsResponse(
            emailMFAEnabled: false,
            totpMFAEnabled: false
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.Authentication.getMFAMethods(stateToken: nil)
        )
        
        // When
        let response = try await sut.getMFAMethods()
        
        // Then
        #expect(response.emailMFAEnabled == false)
        #expect(response.totpMFAEnabled == false)
        #expect(response.methods.isEmpty == true)
    }
    
    @Test("Get MFA methods returns available methods when both enabled")
    func testGetMFAMethodsBothEnabled() async throws {
        await setUp()
        
        // Given
        let expectedResponse = MFAMethodsResponse(
            emailMFAEnabled: true,
            totpMFAEnabled: true
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.Authentication.getMFAMethods(stateToken: nil)
        )
        
        // When
        let response = try await sut.getMFAMethods()
        
        // Then
        #expect(response.emailMFAEnabled == true)
        #expect(response.totpMFAEnabled == true)
        #expect(response.methods.contains(.email))
        #expect(response.methods.contains(.totp))
        #expect(response.methods.count == 2)
    }
    
    @Test("Get MFA methods returns available methods when only email enabled")
    func testGetMFAMethodsEmailOnly() async throws {
        await setUp()
        
        // Given
        let expectedResponse = MFAMethodsResponse(
            emailMFAEnabled: true,
            totpMFAEnabled: false
        )
        await mockAPIClient.mockResponse(
            expectedResponse,
            for: Store.Authentication.getMFAMethods(stateToken: nil)
        )
        
        // When
        let response = try await sut.getMFAMethods()
        
        // Then
        #expect(response.emailMFAEnabled == true)
        #expect(response.totpMFAEnabled == false)
        #expect(response.methods.contains(.email))
        #expect(response.methods.count == 1)
    }
} 