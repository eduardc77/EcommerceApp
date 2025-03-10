import FluentKit

struct AddEmailVerificationEnabled: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user")
            .field("email_verification_enabled", .bool, .required, .sql(.default(false)))
            .update()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("user")
            .deleteField("email_verification_enabled")
            .update()
    }
} 