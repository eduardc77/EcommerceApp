import FluentKit

struct CreateSession: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("sessions")
            .id()
            .field("user_id", .uuid, .required, .references("user", "id", onDelete: .cascade))
            .field("device_name", .string, .required)
            .field("ip_address", .string, .required)
            .field("user_agent", .string, .required)
            .field("token_id", .string, .required)
            .field("is_active", .bool, .required, .sql(.default(true)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .field("last_used_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("sessions").delete()
    }
} 