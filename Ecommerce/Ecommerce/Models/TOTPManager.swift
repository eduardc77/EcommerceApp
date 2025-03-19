import Foundation
import Observation
import Networking

/// Represents the data needed for TOTP setup
public struct TOTPSetupData {
    public let qrCode: String
    public let secret: String
}

/// Errors that can occur during TOTP operations
public enum TOTPError: LocalizedError {
    case invalidCode
    case setupFailed
    case verificationFailed
    case alreadyEnabled
    case notEnabled
    case networkError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid verification code. Please try again."
        case .setupFailed:
            return "Failed to set up two-factor authentication. Please try again."
        case .verificationFailed:
            return "Verification failed. Please make sure you entered the correct code."
        case .alreadyEnabled:
            return "Two-factor authentication is already enabled."
        case .notEnabled:
            return "Two-factor authentication is not enabled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

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
    
    /// Sets up TOTP 2FA and returns the setup data
    /// - Returns: Setup data containing QR code and secret
    /// - Throws: TOTPError if setup fails
    public func setupTOTP() async throws -> TOTPSetupData {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            if isEnabled {
                throw TOTPError.alreadyEnabled
            }
            
            let response = try await totpService.setup()

            return TOTPSetupData(qrCode: response.qrCodeUrl, secret: response.secret)
        } catch let error as TOTPError {
            self.error = error
            throw error
        } catch let error as NetworkError {
            let wrappedError = TOTPError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = TOTPError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Verifies and enables TOTP 2FA
    /// - Parameter code: The 6-digit verification code
    /// - Throws: TOTPError if verification fails
    public func verifyAndEnableTOTP(code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            if isEnabled {
                throw TOTPError.alreadyEnabled
            }
            
            // Single call to verify and enable
            _ = try await totpService.verify(code: code)
            isEnabled = true
        } catch let error as TOTPError {
            self.error = error
            throw error
        } catch let error as NetworkError {
            let wrappedError = TOTPError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = TOTPError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Verifies a TOTP code
    /// - Parameter code: The 6-digit verification code
    /// - Throws: TOTPError if verification fails
    public func verifyTOTP(_ code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            if !isEnabled {
                throw TOTPError.notEnabled
            }
            _ = try await totpService.verify(code: code)
        } catch let error as TOTPError {
            self.error = error
            throw error
        } catch let error as NetworkError {
            let wrappedError = TOTPError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = TOTPError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Verifies a TOTP code during login
    /// - Parameter code: The 6-digit verification code
    /// - Throws: TOTPError if verification fails
    public func verifyTOTPForLogin(_ code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            _ = try await totpService.verify(code: code)
        } catch let error as TOTPError {
            self.error = error
            throw error
        } catch let error as NetworkError {
            let wrappedError = TOTPError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = TOTPError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Fetches the current TOTP status from the server
    public func getTOTPStatus() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let status = try await totpService.getStatus()
            isEnabled = status.enabled
        } catch {
            self.error = error
        }
    }
    
    /// Disables TOTP 2FA
    /// - Parameter code: The 6-digit verification code to confirm disabling 2FA
    /// - Throws: TOTPError if disabling fails
    public func disableTOTP(code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            if !isEnabled {
                throw TOTPError.notEnabled
            }
            
            _ = try await totpService.disable(code: code)
            isEnabled = false
        } catch let error as TOTPError {
            self.error = error
            throw error
        } catch let error as NetworkError {
            let wrappedError = TOTPError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = TOTPError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
} 
