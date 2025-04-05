import Foundation
import Hummingbird
import HummingbirdFluent

/// Service for managing Multi-Factor Authentication state and recovery codes
struct MFAService {
    let fluent: HummingbirdFluent.Fluent
    
    init(fluent: HummingbirdFluent.Fluent) {
        self.fluent = fluent
    }
    
    /// Check if any MFA method is enabled for the user
    func isAnyMFAEnabled(for user: User) -> Bool {
        return user.totpMFAEnabled || user.emailMFAEnabled // Add new methods here
    }
    
    /// Handle MFA method disablement
    /// Call this after disabling any MFA method
    func handleMFADisabled(for user: User) async throws {
        // If no MFA methods are enabled anymore, delete recovery codes
        if !isAnyMFAEnabled(for: user) {
            try await deleteUnusedRecoveryCodes(for: user)
        }
    }
    
    /// Generate new recovery codes for a user
    func generateRecoveryCodes(for user: User) async throws -> [String] {
        let userID = try user.requireID()
        
        // Delete any existing unused recovery codes
        try await deleteUnusedRecoveryCodes(for: user)
        
        // Generate new codes
        let plainCodes = MFARecoveryCode.generateCodes()
        let expirationDate = Date().addingTimeInterval(TimeInterval(365 * 24 * 60 * 60)) // 1 year
        
        // Store hashed codes
        for code in plainCodes {
            let hashedCode = try MFARecoveryCode.hashCode(code)
            let recoveryCode = MFARecoveryCode(
                userID: userID,
                code: hashedCode,
                expiresAt: expirationDate
            )
            try await recoveryCode.save(on: fluent.db())
        }
        
        return plainCodes
    }
    
    /// Delete all unused recovery codes for a user
    private func deleteUnusedRecoveryCodes(for user: User) async throws {
        try await MFARecoveryCode.query(on: fluent.db())
            .filter(\.$user.$id, .equal, try user.requireID())
            .filter(\.$used, .equal, false)
            .delete()
    }
} 