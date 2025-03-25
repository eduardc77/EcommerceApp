import Foundation
import Hummingbird
import Logging

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
    
    /// Add a token to the blacklist with uniqueness constraint on JTI
    /// - Parameters:
    ///   - token: The JWT token to blacklist
    ///   - jti: The JWT ID (jti) claim from the token
    ///   - expiresAt: When the token expires (typically from JWT exp claim)
    ///   - reason: The reason for blacklisting the token
    /// - Throws: Error if the JTI is already blacklisted
    func blacklistWithUniqueness(_ token: String, jti: String, expiresAt: Date, reason: TokenStore.BlacklistReason) async throws
    
    /// Clean up expired tokens from the store
    func cleanup() async
}

/// Thread-safe in-memory implementation of token blacklisting
/// This store maintains a list of invalidated tokens and their expiration dates
/// to prevent token reuse and enforce security policies.
actor TokenStore: TokenStoreProtocol {
    /// Thread-safe storage for blacklisted tokens
    /// Maps token strings to their metadata
    private var blacklistedTokens: [String: BlacklistedToken] = [:]
    
    /// Set of blacklisted JTIs for enforcing uniqueness
    private var blacklistedJTIs: Set<String> = []
    
    /// Maximum number of tokens to store in memory
    /// When this limit is reached, cleanup will be triggered
    private let maxTokens: Int
    
    /// Interval between cleanup operations (5 minutes by default)
    /// Cleanup removes expired tokens from the store
    private let cleanupInterval: TimeInterval
    private var lastCleanupTime: Date = Date()
    
    /// Logger for token store operations
    private let logger: Logger
    
    init(
        maxTokens: Int = 10000,
        cleanupInterval: TimeInterval = 300,
        logger: Logger? = nil
    ) {
        self.maxTokens = maxTokens
        self.cleanupInterval = cleanupInterval
        self.logger = logger ?? Logger(label: "app.token-store")
    }
    
    /// Metadata for a blacklisted token
    private struct BlacklistedToken: Codable {
        let token: String
        let jti: String?
        let expiresAt: Date
        let reason: BlacklistReason
        
        var isExpired: Bool {
            Date() >= expiresAt
        }
    }
    
    /// Reason why a token was blacklisted
    enum BlacklistReason: String, Codable {
        case signOut
        case tokenVersionChange
        case passwordChanged
        case userRevoked
        case authenticationCancelled
        case sessionRevoked
    }
    
    /// Check if a token is blacklisted
    /// - Parameter token: The JWT token to check
    /// - Returns: True if the token is blacklisted and not expired
    public func isBlacklisted(_ token: String) async -> Bool {
        // Perform cleanup if needed
        if Date().timeIntervalSince(lastCleanupTime) > cleanupInterval {
            await cleanup()
        }
        
        // Check if token is in the blacklist and not expired
        if let blacklistedToken = blacklistedTokens[token] {
            if blacklistedToken.expiresAt > Date() {
                logger.debug("Token found in blacklist and is still valid")
                return true
            } else {
                // Token is expired, remove it from blacklist
                blacklistedTokens.removeValue(forKey: token)
                if let jti = blacklistedToken.jti {
                    blacklistedJTIs.remove(jti)
                }
                logger.debug("Removed expired token from blacklist")
                return false
            }
        }
        
        return false
    }
    
    /// Add a token to the blacklist
    /// - Parameters:
    ///   - token: The JWT token to blacklist
    ///   - expiresAt: When the token expires (typically from JWT exp claim)
    ///   - reason: The reason for blacklisting the token
    public func blacklist(_ token: String, expiresAt: Date, reason: BlacklistReason) async {
        // Don't blacklist already expired tokens
        if expiresAt < Date() {
            logger.warning("Attempted to blacklist an already expired token")
            return
        }
        
        // Check if we need to clean up before adding a new token
        if blacklistedTokens.count >= maxTokens {
            logger.notice("Token store reached capacity (\(maxTokens)), cleaning up before adding new token")
            await cleanup()
            
            // If still at capacity after cleanup, log a warning
            if blacklistedTokens.count >= maxTokens {
                logger.warning("Token store still at capacity after cleanup, oldest tokens may be removed")
            }
        }
        
        // Create blacklisted token record
        let blacklistedToken = BlacklistedToken(
            token: token,
            jti: nil,
            expiresAt: expiresAt,
            reason: reason
        )
        
        // Add to blacklist
        blacklistedTokens[token] = blacklistedToken
        logger.debug("Token blacklisted until \(expiresAt.ISO8601Format()) for reason: \(reason.rawValue)")
    }
    
    /// Add a token to the blacklist with uniqueness constraint on JTI
    /// - Parameters:
    ///   - token: The JWT token to blacklist
    ///   - jti: The JWT ID (jti) claim from the token
    ///   - expiresAt: When the token expires (typically from JWT exp claim)
    ///   - reason: The reason for blacklisting the token
    /// - Throws: Error if the JTI is already blacklisted
    public func blacklistWithUniqueness(_ token: String, jti: String, expiresAt: Date, reason: BlacklistReason) async throws {
        // Don't blacklist already expired tokens
        if expiresAt < Date() {
            logger.warning("Attempted to blacklist an already expired token")
            return
        }
        
        // Check if JTI is already blacklisted
        if blacklistedJTIs.contains(jti) {
            logger.warning("Attempted to reuse JTI: \(jti)")
            throw HTTPError(.unauthorized, message: "Token has already been used")
        }
        
        // Check if we need to clean up before adding a new token
        if blacklistedTokens.count >= maxTokens {
            logger.notice("Token store reached capacity (\(maxTokens)), cleaning up before adding new token")
            await cleanup()
            
            // If still at capacity after cleanup, log a warning
            if blacklistedTokens.count >= maxTokens {
                logger.warning("Token store still at capacity after cleanup, oldest tokens may be removed")
            }
        }
        
        // Create blacklisted token record
        let blacklistedToken = BlacklistedToken(
            token: token,
            jti: jti,
            expiresAt: expiresAt,
            reason: reason
        )
        
        // Add to blacklist and JTI set
        blacklistedTokens[token] = blacklistedToken
        blacklistedJTIs.insert(jti)
        logger.debug("Token blacklisted with JTI \(jti) until \(expiresAt.ISO8601Format()) for reason: \(reason.rawValue)")
    }
    
    /// Clean up expired tokens from the store
    public func cleanup() async {
        lastCleanupTime = Date()
        let now = Date()
        
        // Find and remove expired tokens
        let expiredTokens = blacklistedTokens.filter { $0.value.expiresAt < now }
        
        if !expiredTokens.isEmpty {
            for (key, token) in expiredTokens {
                blacklistedTokens.removeValue(forKey: key)
                if let jti = token.jti {
                    blacklistedJTIs.remove(jti)
                }
            }
            
            logger.debug("Cleaned up \(expiredTokens.count) expired tokens from blacklist")
        }
    }
    
    /// Get statistics about the blacklist
    /// - Returns: Tuple containing total tokens, expired tokens, and active tokens
    func getStats() -> (total: Int, expired: Int, active: Int) {
        let total = blacklistedTokens.count
        let expired = blacklistedTokens.values.filter { $0.isExpired }.count
        return (total: total, expired: expired, active: total - expired)
    }
} 
