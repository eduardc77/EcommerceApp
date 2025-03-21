import Foundation
import FluentKit
import Crypto

/// Model for storing email verification codes
final class EmailVerificationCode: Model, @unchecked Sendable {
    static let schema = "email_verification_codes"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "code")
    var code: String
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "type")
    var type: String
    
    @Field(key: "attempts")
    var attempts: Int
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @Field(key: "last_requested_at")
    var lastRequestedAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() {}
    
    init(id: UUID? = nil, userID: UUID, code: String, type: String, expiresAt: Date) {
        self.id = id
        self.$user.id = userID
        self.code = code
        self.type = type
        self.attempts = 0
        self.expiresAt = expiresAt
        self.lastRequestedAt = Date()
    }
    
    /// Generate a random 6-digit code
    static func generateCode() -> String {
        // Only use hardcoded code in testing environment
        if Environment.current.isTesting {
            return "123456"
        }
        
        // For all other environments (development, staging, production)
        // use cryptographically secure random number generator
        var generator = SystemRandomNumberGenerator()
        let randomNumber = UInt32.random(in: 0...999999, using: &generator)
        
        // Pad with leading zeros to ensure 6 digits
        return String(format: "%06d", randomNumber)
    }
    
    /// Check if the code is expired
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    /// Check if too many attempts have been made
    var hasExceededAttempts: Bool {
        attempts >= 3
    }
    
    /// Check if we're within the cooldown period (120 seconds)
    var isWithinCooldown: Bool {
        guard let lastRequested = lastRequestedAt else { return false }
        return Date().timeIntervalSince(lastRequested) < 120
    }
    
    /// Get remaining cooldown time in seconds
    var remainingCooldown: Int {
        guard let lastRequested = lastRequestedAt else { return 0 }
        let elapsed = Date().timeIntervalSince(lastRequested)
        let remaining = 120 - Int(elapsed)
        return max(0, remaining)
    }
    
    /// Increment the number of attempts
    func incrementAttempts() {
        attempts += 1
    }
    
    /// Update the last requested time
    func updateLastRequested() {
        lastRequestedAt = Date()
    }
}

// MARK: - Migration
extension EmailVerificationCode {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(EmailVerificationCode.schema)
                .id()
                .field("code", .string, .required)
                .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("type", .string, .required)
                .field("attempts", .int, .required)
                .field("expires_at", .datetime, .required)
                .field("last_requested_at", .datetime)
                .field("created_at", .datetime)
                .unique(on: "user_id", "type", name: "user_type_idx")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(EmailVerificationCode.schema).delete()
        }
    }
} 
