import FluentKit

struct CreateMFARecoveryCodes: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("mfa_recovery_codes")
            .id()
            .field("user_id", .uuid, .required, .references("user", "id", onDelete: .cascade))
            .field("code", .string, .required)
            .field("used", .bool, .required, .sql(.default(false)))
            .field("used_at", .datetime)
            .field("failed_attempts", .int, .required, .sql(.default(0)))
            .field("expires_at", .datetime)
            .field("used_from_ip", .string)
            .field("used_from_user_agent", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("mfa_recovery_codes").delete()
    }
} 