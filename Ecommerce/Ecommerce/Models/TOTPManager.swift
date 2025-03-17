import Observation
import Networking

/// Manages Two-Factor Authentication (2FA) using Time-based One-Time Passwords (TOTP)
@Observable
@MainActor
public final class TOTPManager {
    private let totpService: TOTPServiceProtocol
    
    /// Indicates if a TOTP operation is in progress
    private(set) public var isLoading = false
    
    /// The last error that occurred during TOTP operations
    private(set) public var error: Error?
    
    /// Whether 2FA is currently enabled for the user
    private(set) public var isEnabled = false
    
    public init(totpService: TOTPServiceProtocol) {
        self.totpService = totpService
    }
    
    /// Resets all state variables to their default values
    public func reset() {
        isLoading = false
        error = nil
        isEnabled = false
    }
    
    /// Sets up TOTP 2FA and returns the QR code URL for initial setup
    /// - Returns: QR code URL for scanning with authenticator app, nil if setup fails
    public func setupTOTP() async -> String? {
        isLoading = true
        error = nil
        do {
            let response = try await totpService.setup()
            return response.qrCodeUrl
        } catch {
            self.error = error
            return nil
        }
        isLoading = false
    }
    
    /// Verifies a TOTP code
    /// - Parameter code: The 6-digit TOTP code to verify
    /// - Returns: Whether the verification was successful
    public func verifyTOTP(_ code: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.verify(code: code)
            return true
        } catch {
            self.error = error
            return false
        }
        isLoading = false
    }
    
    /// Fetches the current TOTP status from the server
    public func getTOTPStatus() async {
        isLoading = true
        error = nil
        do {
            let status = try await totpService.getStatus()
            isEnabled = status.enabled
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    /// Enables TOTP 2FA with a verification code
    /// - Parameter code: The 6-digit TOTP code to verify and enable
    /// - Returns: Whether enabling was successful
    public func enableTOTP(_ code: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.enable(code: code)
            isEnabled = true
            return true
        } catch {
            self.error = error
            return false
        }
        isLoading = false
    }
    
    /// Disables TOTP 2FA with a verification code
    /// - Parameter code: The 6-digit TOTP code to verify and disable
    /// - Returns: Whether disabling was successful
    public func disableTOTP(_ code: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.disable(code: code)
            isEnabled = false
            return true
        } catch {
            self.error = error
            return false
        }
        isLoading = false
    }
} 