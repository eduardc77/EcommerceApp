import Foundation
import Observation
import Networking
import OSLog

/// Errors that can occur during recovery code operations
public enum RecoveryCodesError: LocalizedError {
    case invalidCode
    case generationFailed
    case verificationFailed
    case networkError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid recovery code. Please check and try again."
        case .generationFailed:
            return "Failed to generate recovery codes. Please try again."
        case .verificationFailed:
            return "Failed to verify recovery code. Please try again."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Represents a recovery code
public struct RecoveryCode: Identifiable {
    public let id: String
    public let code: String
    public let isUsed: Bool
}

/// Manages recovery codes for MFA
@Observable
@MainActor
public class RecoveryCodesManager {
    private let recoveryCodesService: RecoveryCodesServiceProtocol
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Ecommerce", category: "RecoveryCodesManager")
    
    /// Indicates if a recovery code operation is in progress
    public private(set) var isLoading = false
    
    /// The last error that occurred during recovery code operations
    public private(set) var error: Error?
    
    /// List of available recovery codes
    public var codes: [RecoveryCode] = []
    
    /// Message from the server about the recovery codes
    public private(set) var message: String = ""
    
    /// When the recovery codes expire
    public private(set) var expiresAt: String = ""
    
    /// Current status of recovery codes
    public private(set) var status: RecoveryMFAStatusResponse?
    
    /// Indicates if recovery codes should be regenerated (e.g., due to expiration)
    public private(set) var shouldRegenerate: Bool = false
    
    public init(recoveryCodesService: RecoveryCodesServiceProtocol) {
        self.recoveryCodesService = recoveryCodesService
    }
    
    /// Resets all state variables to their default values
    public func reset() {
        isLoading = false
        error = nil
        codes = []
        message = ""
        expiresAt = ""
        status = nil
        shouldRegenerate = false
    }
    
    /// Gets the current status of recovery codes
    public func getStatus() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            // Try to get status directly first
            status = try await recoveryCodesService.getStatus()
            
            // Check if codes are about to expire by getting detailed status
            if status?.hasValidCodes == true {
                let detailedStatus = try await recoveryCodesService.listCodes()
                shouldRegenerate = detailedStatus.shouldRegenerate
            }
        } catch {
            // If status call fails (e.g. decoding error), fallback to listCodes
            let detailedStatus = try await recoveryCodesService.listCodes()
            shouldRegenerate = detailedStatus.shouldRegenerate
            
            // Try to get MFA methods to determine if MFA is enabled
            do {
                let mfaMethods = try await recoveryCodesService.getMFAMethods()
                status = RecoveryMFAStatusResponse(
                    enabled: mfaMethods.emailMFAEnabled || mfaMethods.totpMFAEnabled,
                    hasValidCodes: detailedStatus.validCodes > 0
                )
            } catch {
                // If all attempts fail, set enabled to false as a safe default
                status = RecoveryMFAStatusResponse(
                    enabled: false,
                    hasValidCodes: detailedStatus.validCodes > 0
                )
            }
        }
    }
    
    /// Generates new recovery codes
    /// - Parameter password: The user's password for verification
    public func generateCodes(password: String = "") async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response: RecoveryCodesResponse
            if password.isEmpty {
                response = try await recoveryCodesService.generateCodes()
            } else {
                response = try await recoveryCodesService.regenerateCodes(password: password)
            }
            
            codes = response.codes.enumerated().map { index, code in
                RecoveryCode(id: String(index), code: code, isUsed: false)
            }
            message = response.message
            expiresAt = response.expiresAt
            
            // Get fresh status after generating codes
            status = try await recoveryCodesService.getStatus()
            shouldRegenerate = false
        } catch let error as NetworkError {
            let wrappedError = RecoveryCodesError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = RecoveryCodesError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Verifies a recovery code during sign-in
    /// - Parameters:
    ///   - code: The recovery code to verify
    ///   - stateToken: The state token from the sign-in attempt
    /// - Returns: The authentication response
    public func verifyCode(code: String, stateToken: String) async throws -> AuthResponse {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            return try await recoveryCodesService.verifyCode(code: code, stateToken: stateToken)
        } catch let error as NetworkError {
            let wrappedError = RecoveryCodesError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = RecoveryCodesError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
    
    /// Gets the current list of recovery codes
    public func getCodes() async throws {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        do {
            let response = try await recoveryCodesService.listCodes()
            shouldRegenerate = response.shouldRegenerate
            
            // Create RecoveryCode objects from the response
            // Since we don't get the actual codes from listCodes, we'll just track the count
            codes = (0..<response.validCodes).map { index in
                RecoveryCode(
                    id: String(index),
                    code: "••••-••••-••••-••••", // Placeholder for security
                    isUsed: false
                )
            }
            
            // Only update hasValidCodes, preserve the enabled status from getStatus()
            if let currentStatus = status {
                status = RecoveryMFAStatusResponse(
                    enabled: currentStatus.enabled,
                    hasValidCodes: response.validCodes > 0
                )
            } else {
                // If no status exists yet, get it from the service
                status = try await recoveryCodesService.getStatus()
            }
        } catch let error as NetworkError {
            let wrappedError = RecoveryCodesError.networkError(error)
            self.error = wrappedError
            throw wrappedError
        } catch {
            let wrappedError = RecoveryCodesError.unknown(error)
            self.error = wrappedError
            throw wrappedError
        }
    }
} 
