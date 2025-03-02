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

/// Thread-safe in-memory implementation of token blacklisting with persistence
actor TokenStore: TokenStoreProtocol {
    /// Thread-safe storage for blacklisted tokens
    private var blacklistedTokens: [String: BlacklistedToken] = [:]
    private var isInitialized = false
    
    /// Maximum number of tokens to store in memory
    private let maxTokens: Int
    
    /// Interval between cleanup operations (5 minutes)
    private let cleanupInterval: TimeInterval
    private var lastCleanupTime: Date = Date()
    
    /// File URL for persistence
    private let persistenceURL: URL?
    
    init(
        maxTokens: Int = 10000,
        cleanupInterval: TimeInterval = 300,
        persistenceURL: URL? = nil
    ) {
        self.maxTokens = maxTokens
        self.cleanupInterval = cleanupInterval
        
        // Use provided URL or create default
        if let persistenceURL = persistenceURL {
            self.persistenceURL = persistenceURL
        } else {
            let fileManager = FileManager.default
            do {
                let appSupport = try fileManager.url(for: .applicationSupportDirectory, 
                                                   in: .userDomainMask, 
                                                   appropriateFor: nil, 
                                                   create: true)
                self.persistenceURL = appSupport.appendingPathComponent("blacklisted_tokens.json")
            } catch {
                print("⚠️ Failed to create persistence URL, falling back to temporary directory: \(error)")
                self.persistenceURL = FileManager.default.temporaryDirectory.appendingPathComponent("blacklisted_tokens.json")
            }
        }
        
        // Initialize asynchronously
        Task {
            await initialize()
        }
    }
    
    /// Metadata for a blacklisted token
    private struct BlacklistedToken: Codable {
        let token: String
        let expiresAt: Date
        let reason: BlacklistReason
        
        var isExpired: Bool {
            Date() >= expiresAt
        }
    }
    
    /// Reason why a token was blacklisted
    enum BlacklistReason: String, Codable {
        case logout
        case tokenVersionChange
    }
    
    private func initialize() async {
        guard !isInitialized else { return }
        await loadPersistedTokens()
        isInitialized = true
    }
    
    func isBlacklisted(_ token: String) async -> Bool {
        // Ensure initialization is complete
        if !isInitialized {
            await initialize()
        }
        
        await cleanupIfNeeded()
        
        guard let blacklistedToken = blacklistedTokens[token] else {
            return false
        }
        
        if blacklistedToken.isExpired {
            blacklistedTokens.removeValue(forKey: token)
            await persistTokens()
            return false
        }
        
        return true
    }
    
    func blacklist(_ token: String, expiresAt: Date, reason: BlacklistReason) async {
        // Ensure initialization is complete
        if !isInitialized {
            await initialize()
        }
        
        await cleanupIfNeeded()
        
        // Only blacklist if expiration is in the future
        guard expiresAt > Date() else { return }
        
        // Check if we need to make room for new tokens
        if blacklistedTokens.count >= maxTokens {
            // Remove oldest tokens first
            let sortedTokens = blacklistedTokens.sorted { $0.value.expiresAt < $1.value.expiresAt }
            let tokensToRemove = sortedTokens.prefix(max(1, maxTokens / 10))
            for token in tokensToRemove {
                blacklistedTokens.removeValue(forKey: token.key)
            }
        }
        
        let blacklistedToken = BlacklistedToken(
            token: token,
            expiresAt: expiresAt,
            reason: reason
        )
        
        blacklistedTokens[token] = blacklistedToken
        await persistTokens()
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
        
        // Persist changes
        await persistTokens()
    }
    
    private func persistTokens() async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(blacklistedTokens)
            try data.write(to: persistenceURL!, options: .atomicWrite)
        } catch {
            print("Failed to persist blacklisted tokens: \(error)")
        }
    }
    
    private func loadPersistedTokens() async {
        do {
            let data = try Data(contentsOf: persistenceURL!)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            blacklistedTokens = try decoder.decode([String: BlacklistedToken].self, from: data)
            
            // Cleanup expired tokens immediately after loading
            await cleanup()
        } catch {
            print("No persisted tokens found or failed to load: \(error)")
            blacklistedTokens = [:]
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