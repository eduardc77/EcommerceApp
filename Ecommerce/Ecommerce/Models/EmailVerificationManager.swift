import Observation
import Networking

/// Manages the email verification process and state
@Observable
@MainActor  // Ensure all state mutations happen on main thread
public final class EmailVerificationManager {
    private let emailVerificationService: EmailVerificationServiceProtocol

    /// Indicates if a verification operation is in progress
    private(set) public var isLoading = false

    /// Whether email verification is currently required
    public var requiresEmailVerification = false

    /// Whether email 2FA is enabled for the account
    private(set) public var is2FAEnabled = false

    public init(emailVerificationService: EmailVerificationServiceProtocol) {
        self.emailVerificationService = emailVerificationService
    }

    /// Resets verification state
    public func reset() {
        requiresEmailVerification = false
        is2FAEnabled = false
        isLoading = false
    }

    /// Gets the current 2FA status from the server
    public func get2FAStatus() async throws {
        isLoading = true
        defer { isLoading = false }

        let status = try await emailVerificationService.get2FAStatus()
        is2FAEnabled = status.enabled
    }

    /// Sets up 2FA email verification
    public func setup2FA() async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.setup2FA()
    }

    /// Verifies the code and enables 2FA
    public func verify2FA(code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.verify2FA(code: code)
        is2FAEnabled = true
    }

    /// Disables 2FA email verification
    public func disable2FA(code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.disable2FA(code: code)
        is2FAEnabled = false
    }

    /// Skips the email verification requirement but maintains the requirement state
    public func skipEmailVerification() {
        requiresEmailVerification = true
    }

    /// Fetches the initial verification status from the server
    public func getInitialStatus() async throws {
        isLoading = true
        defer { isLoading = false }

        let status = try await emailVerificationService.getInitialStatus()
        requiresEmailVerification = !status.verified
    }

    /// Verifies initial email during registration
    /// - Parameters:
    ///   - email: The email address to verify
    ///   - code: The verification code
    public func verifyInitialEmail(email: String, code: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.verifyInitialEmail(email: email, code: code)
        requiresEmailVerification = false
    }

    /// Requests a new verification code be sent
    /// - Parameter email: The email address to send the code to
    public func resendVerificationEmail(email: String) async throws {
        isLoading = true
        defer { isLoading = false }

        _ = try await emailVerificationService.resendVerificationEmail(email: email)
    }

    /// Handles email updates by resetting verification state and sending a new code
    /// - Parameter email: The new email address to verify
    public func handleEmailUpdate(email: String) async throws {
        requiresEmailVerification = true
        isLoading = true
        defer { isLoading = false }

        try await resendVerificationEmail(email: email)
    }
}
