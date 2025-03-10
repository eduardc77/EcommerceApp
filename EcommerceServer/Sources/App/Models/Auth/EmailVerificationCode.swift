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
    }
    
    /// Generate a random 6-digit code
    static func generateCode() -> String {
        // For test environment, use deterministic code
        if ProcessInfo.processInfo.environment["APP_ENV"] == "testing" {
            return "123456"  // Test verification code
        }
        
        // For production/development, generate random 6-digit code
        var random = SystemRandomNumberGenerator()
        let code = UInt32.random(in: 100000...999999, using: &random)
        return String(format: "%06d", code)
    }
    
    /// Check if the code is expired
    var isExpired: Bool {
        Date() > expiresAt
    }
    
    /// Check if too many attempts have been made
    var hasExceededAttempts: Bool {
        attempts >= 5
    }
    
    /// Increment the number of attempts
    func incrementAttempts() {
        attempts += 1
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
                .field("created_at", .datetime)
                .unique(on: "user_id", "type", name: "user_type_idx")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(EmailVerificationCode.schema).delete()
        }
    }
} 