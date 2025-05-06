import Foundation
@testable import Networking
@testable import Ecommerce

actor MockTOTPService: TOTPServiceProtocol {
    // MARK: - Call Tracking
    private(set) var enableTOTPCallCount = 0
    private(set) var verifyTOTPCallCount = 0
    private(set) var verifyTOTPReceivedCodes: [String] = []
    private(set) var disableTOTPCallCount = 0
    private(set) var disableTOTPReceivedPasswords: [String] = []
    private(set) var getTOTPStatusCallCount = 0
    
    // MARK: - Mock State
    private var error: Error?
    private var isTOTPEnabled = false
    
    func setTOTPEnabled(_ enabled: Bool) {
        isTOTPEnabled = enabled
    }
    
    func setEnableError(_ error: NetworkError) {
        self.error = error
    }
    
    func setVerifyError(_ error: TOTPError) {
        self.error = error
    }
    
    // MARK: - Protocol Methods
    func enableTOTP() async throws -> TOTPSetupResponse {
        enableTOTPCallCount += 1
        
        if isTOTPEnabled {
            throw TOTPError.alreadyEnabled
        }
        
        if let error = error {
            throw error
        }
        
        isTOTPEnabled = true
        return TOTPSetupResponse(
            secret: "test-secret",
            qrCodeUrl: "test-qr-code"
        )
    }
    
    func verifyTOTP(code: String) async throws -> MFAVerifyResponse {
        verifyTOTPCallCount += 1
        verifyTOTPReceivedCodes.append(code)
        
        if let error = error {
            throw error
        }
        
        isTOTPEnabled = true
        return MFAVerifyResponse(
            message: "Verification successful",
            success: true,
            recoveryCodes: ["AAAA-BBBB", "CCCC-DDDD"]
        )
    }
    
    func disableTOTP(password: String) async throws -> MessageResponse {
        disableTOTPCallCount += 1
        disableTOTPReceivedPasswords.append(password)
        
        if !isTOTPEnabled {
            throw TOTPError.notEnabled
        }
        
        if let error = error {
            throw error
        }
        
        isTOTPEnabled = false
        return MessageResponse(
            message: "TOTP disabled successfully",
            success: true
        )
    }
    
    func getTOTPStatus() async throws -> TOTPStatusResponse {
        getTOTPStatusCallCount += 1
        
        if let error = error {
            throw error
        }
        
        return TOTPStatusResponse(totpMFAEnabled: isTOTPEnabled)
    }
}

// MARK: - Mock Error
extension MockTOTPService {
    enum MockError: Error {
        case notImplemented
    }
}
