import Foundation
import Hummingbird

/// Protocol defining token storage operations for managing JWT token blacklisting
protocol TokenStoreProtocol {
    /// Check if a token is blacklisted
    /// - Parameter token: The JWT token to check
    /// - Returns: True if the token is blacklisted and not expired
    func isBlacklisted(_ token: String) async -> Bool
    
    /// Add a token to the blacklist
    /// - Parameters:
    ///   - token: The JWT token to blacklist
    ///   - expiresAt: When the token expires (typically from JWT exp claim)
    ///   - reason: The reason for blacklisting the token
    func blacklist(_ token: String, expiresAt: Date, reason: TokenStore.BlacklistReason) async
    
    /// Clean up expired tokens from the store
    func cleanup() async
}

/// Thread-safe in-memory implementation of token blacklisting
actor TokenStore: TokenStoreProtocol {
    /// Singleton instance for application-wide use
    static let shared = TokenStore()
    
    /// Thread-safe storage for blacklisted tokens
    private var blacklistedTokens: [String: BlacklistedToken] = [:]
    
    /// Interval between cleanup operations (5 minutes)
    private let cleanupInterval: TimeInterval = 300
    private var lastCleanupTime: Date = Date()
    
    /// Metadata for a blacklisted token
    private struct BlacklistedToken {
        let token: String
        let expiresAt: Date
        let reason: BlacklistReason
        
        var isExpired: Bool {
            Date() >= expiresAt
        }
    }
    
    /// Reason why a token was blacklisted
    enum BlacklistReason {
        /// User explicitly logged out
        case logout
        /// User's token version changed (e.g. password change)
        case tokenVersionChange
    }
    
    private init() {}
    
    func isBlacklisted(_ token: String) async -> Bool {
        await cleanupIfNeeded()
        
        guard let blacklistedToken = blacklistedTokens[token] else {
            return false
        }
        
        if blacklistedToken.isExpired {
            blacklistedTokens.removeValue(forKey: token)
            return false
        }
        
        return true
    }
    
    func blacklist(_ token: String, expiresAt: Date) async {
        await blacklist(token, expiresAt: expiresAt, reason: .logout)
    }
    
    func blacklist(_ token: String, expiresAt: Date, reason: BlacklistReason) async {
        await cleanupIfNeeded()
        
        // Only blacklist if expiration is in the future
        guard expiresAt > Date() else { return }
        
        let blacklistedToken = BlacklistedToken(
            token: token,
            expiresAt: expiresAt,
            reason: reason
        )
        
        blacklistedTokens[token] = blacklistedToken
    }
    
    private func cleanupIfNeeded() async {
        let now = Date()
        guard now.timeIntervalSince(lastCleanupTime) >= cleanupInterval else {
            return
        }
        
        await cleanup()
    }
    
    func cleanup() async {
        // Remove expired tokens
        blacklistedTokens = blacklistedTokens.filter { !$0.value.isExpired }
        
        // Update last cleanup time
        lastCleanupTime = Date()
    }
    
    /// Get statistics about the blacklist
    /// - Returns: Tuple containing total tokens, expired tokens, and active tokens
    func getStats() -> (total: Int, expired: Int, active: Int) {
        let total = blacklistedTokens.count
        let expired = blacklistedTokens.values.filter { $0.isExpired }.count
        return (total: total, expired: expired, active: total - expired)
    }
} 