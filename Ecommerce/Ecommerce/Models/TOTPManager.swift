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
            return "Failed to set up MFA. Please try again."
        case .verificationFailed:
            return "Verification failed. Please make sure you entered the correct code."
        case .alreadyEnabled:
            return "MFA is already enabled."
        case .notEnabled:
            return "MFA is not enabled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Manages Time-based One-Time Password (TOTP) Multi-Factor Authentication (MFA)
@Observable
@MainActor
public final class TOTPManager {
    private let totpService: TOTPServiceProtocol
    
    /// Indicates if a TOTP operation is in progress
    private(set) public var isLoading = false
    
    /// The last error that occurred during TOTP operations
    private(set) public var error: Error?
    
    /// Whether MFA is currently enabled for the user
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
    
    /// Enables TOTP MFA and returns the setup data
    /// - Returns: Setup data containing QR code and secret
    /// - Throws: TOTPError if setup fails
    public func enableTOTP() async throws -> TOTPSetupData {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            if isEnabled {
                throw TOTPError.alreadyEnabled
            }
            
            let response = try await totpService.enableTOTP()

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

    /// Verifies a TOTP code
    /// - Parameter code: The 6-digit verification code
    /// - Throws: TOTPError if verification fails
    public func verifyTOTP(code: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            _ = try await totpService.verifyTOTP(code: code)
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

    /// Gets the current MFA status from the server
    public func getMFAStatus() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let status = try await totpService.getTOTPStatus()
            isEnabled = status.enabled
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
    
    /// Disables TOTP MFA
    /// - Parameters:
    ///   - code: The 6-digit verification code
    ///   - password: The user's password for verification
    /// - Throws: TOTPError if verification fails
    public func disable(password: String) async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            if !isEnabled {
                throw TOTPError.notEnabled
            }
            
            _ = try await totpService.disableTOTP(password: password)
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
    
    /// Gets the current TOTP status
    /// - Returns: Whether TOTP is currently enabled
    public func getTOTPStatus() async throws -> Bool {
        try await getMFAStatus()
        return isEnabled
    }
}
