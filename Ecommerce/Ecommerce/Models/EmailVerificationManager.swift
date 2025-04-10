import Observation
import Networking

/// Manages the email verification process and state
@Observable
@MainActor  // Ensure all state mutations happen on main thread
public class EmailVerificationManager {
    private let emailVerificationService: EmailVerificationServiceProtocol

    /// Indicates if a verification operation is in progress
    private(set) public var isLoading = false

    /// Whether email verification is currently required
    public var requiresEmailVerification = false

    /// Whether email MFA is enabled for the account
    private(set) public var isEmailMFAEnabled = false

    public init(emailVerificationService: EmailVerificationServiceProtocol) {
        self.emailVerificationService = emailVerificationService
    }

    /// Resets verification state
    public func reset() {
        requiresEmailVerification = false
        isEmailMFAEnabled = false
        isLoading = false
    }

    /// Gets the current MFA status from the server
    public func getEmailMFAStatus() async throws {
        isLoading = true
        defer { isLoading = false }

        let status = try await emailVerificationService.getEmailMFAStatus()
        isEmailMFAEnabled = status.emailMfaEnabled
        requiresEmailVerification = !status.emailVerified
    }

    /// Sets up MFA email verification
    public func enableEmailMFA() async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.enableEmailMFA()
    }

    /// Verifies the code and enables MFA
    /// - Parameters:
    ///   - code: The verification code
    ///   - email: The email address to verify
    /// - Returns: Array of recovery codes
    public func verifyEmailMFA(code: String, email: String) async throws -> [RecoveryCode] {
        isLoading = true
        defer { isLoading = false }

        let response = try await emailVerificationService.verifyEmailMFA(code: code, email: email)
        if response.success {
            isEmailMFAEnabled = true
            if let codes = response.recoveryCodes {
                return codes.enumerated().map { index, code in
                    RecoveryCode(id: String(index), code: code, isUsed: false)
                }
            }
        }
        return []
    }

    /// Disables MFA email verification
    public func disableEmailMFA(password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.disableEmailMFA(password: password)
        isEmailMFAEnabled = false
    }
    
    /// Resends email MFA code
    public func resendEmailMFACode() async throws {
        isLoading = true
        defer { isLoading = false }
        
        _ = try await emailVerificationService.resendEmailMFACode()
    }

    /// Skips the email verification requirement
    public func skipVerification() {
        requiresEmailVerification = false
    }

    /// Gets the initial verification status from the server
    public func getInitialStatus() async throws {
        isLoading = true
        defer { isLoading = false }

        let status = try await emailVerificationService.getInitialStatus()
        requiresEmailVerification = !status.emailVerified
    }
    
    /// Sends the initial verification email
    /// - Parameters:
    ///   - stateToken: The state token from the signup response
    ///   - email: The email address to send the verification code to
    public func sendInitialVerificationEmail(stateToken: String, email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        _ = try await emailVerificationService.sendInitialVerificationEmail(stateToken: stateToken, email: email)
    }

    /// Verifies the initial email address
    /// - Parameters:
    ///   - code: The verification code
    ///   - stateToken: The state token from the signup response
    ///   - email: The email address to verify
    /// - Returns: The authentication response containing tokens on success
    public func verifyInitialEmail(code: String, stateToken: String, email: String) async throws -> AuthResponse {
        isLoading = true
        defer { isLoading = false }
        
        let response = try await emailVerificationService.verifyInitialEmail(code: code, stateToken: stateToken, email: email)
        requiresEmailVerification = false
        return response
    }

    /// Resends the verification email
    /// - Parameters:
    ///   - stateToken: The state token from the signup response
    ///   - email: The email address to send the verification code to
    public func resendVerificationEmail(stateToken: String, email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.resendInitialVerificationEmail(stateToken: stateToken, email: email)
    }
    
}
