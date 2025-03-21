import FluentKit

struct CreateEmailVerificationCode: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("email_verification_codes")
            .id()
            .field("user_id", .uuid, .required, .references("user", "id", onDelete: .cascade))
            .field("code", .string, .required)
            .field("type", .string, .required)
            .field("attempts", .int, .required, .sql(.default(0)))
            .field("expires_at", .datetime, .required)
            .field("last_requested_at", .datetime)
            .field("created_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("email_verification_codes").delete()
    }
} 