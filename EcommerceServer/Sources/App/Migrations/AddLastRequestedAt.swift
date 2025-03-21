import FluentKit

struct AddLastRequestedAt: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("email_verification_codes")
            .field("last_requested_at", .datetime)
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("email_verification_codes")
            .deleteField("last_requested_at")
            .update()
    }
} 