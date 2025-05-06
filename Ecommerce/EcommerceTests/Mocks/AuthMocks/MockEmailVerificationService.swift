@testable import Networking

actor MockEmailVerificationService: EmailVerificationServiceProtocol {
    // MARK: - Call Tracking
    private(set) var getInitialStatusCallCount = 0
    private(set) var getEmailMFAStatusCallCount = 0
    private(set) var sendInitialVerificationEmailCallCount = 0
    private(set) var sendInitialVerificationEmailParams: [(stateToken: String, email: String)] = []
    private(set) var resendInitialVerificationEmailCallCount = 0
    private(set) var resendInitialVerificationEmailParams: [(stateToken: String, email: String)] = []
    private(set) var verifyInitialEmailCallCount = 0
    private(set) var verifyInitialEmailParams: [(code: String, stateToken: String, email: String)] = []
    private(set) var enableEmailMFACallCount = 0
    private(set) var verifyEmailMFACallCount = 0
    private(set) var verifyEmailMFAReceivedCodes: [(code: String, email: String)] = []
    private(set) var disableEmailMFACallCount = 0
    private(set) var disableEmailMFAReceivedPasswords: [String] = []
    private(set) var resendEmailMFACodeCallCount = 0
    
    func getInitialStatus() async throws -> EmailVerificationStatusResponse {
        getInitialStatusCallCount += 1
        return EmailVerificationStatusResponse(emailMFAEnabled: false, emailVerified: true)
    }
    
    func getEmailMFAStatus() async throws -> EmailVerificationStatusResponse {
        getEmailMFAStatusCallCount += 1
        return EmailVerificationStatusResponse(emailMFAEnabled: false, emailVerified: true)
    }
    
    func sendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        sendInitialVerificationEmailCallCount += 1
        sendInitialVerificationEmailParams.append((stateToken: stateToken, email: email))
        return MessageResponse(message: "Verification email sent", success: true)
    }
    
    func resendInitialVerificationEmail(stateToken: String, email: String) async throws -> MessageResponse {
        resendInitialVerificationEmailCallCount += 1
        resendInitialVerificationEmailParams.append((stateToken: stateToken, email: email))
        return MessageResponse(message: "Verification email resent", success: true)
    }
    
    func verifyInitialEmail(code: String, stateToken: String, email: String) async throws -> AuthResponse {
        verifyInitialEmailCallCount += 1
        verifyInitialEmailParams.append((code: code, stateToken: stateToken, email: email))
        return AuthResponse(status: AuthResponse.STATUS_SUCCESS)
    }
    
    func enableEmailMFA() async throws -> MessageResponse {
        enableEmailMFACallCount += 1
        return MessageResponse(message: "Email MFA enabled", success: true)
    }
    
    func verifyEmailMFA(code: String, email: String) async throws -> MFAVerifyResponse {
        verifyEmailMFACallCount += 1
        verifyEmailMFAReceivedCodes.append((code: code, email: email))
        return MFAVerifyResponse(message: "Email MFA verified", success: true)
    }
    
    func disableEmailMFA(password: String) async throws -> MessageResponse {
        disableEmailMFACallCount += 1
        disableEmailMFAReceivedPasswords.append(password)
        return MessageResponse(message: "Email MFA disabled", success: true)
    }
    
    func resendEmailMFACode() async throws -> MessageResponse {
        resendEmailMFACodeCallCount += 1
        return MessageResponse(message: "Code resent", success: true)
    }
}
