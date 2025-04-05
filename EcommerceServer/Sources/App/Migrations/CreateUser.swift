import FluentKit

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user")
            .id()
            .field("username", .string, .required)
            .field("display_name", .string, .required)
            .field("email", .string, .required)
            .field("profile_picture", .string, .sql(.default("https://api.dicebear.com/7.x/avataaars/png")))
            .field("role", .string, .required)
            .field("password_hash", .string)
            .field("password_updated_at", .datetime)
            .field("password_history", .array(of: .string))
            .field("email_verified", .bool, .required, .sql(.default(false)))
            .field("failed_sign_in_attempts", .int, .required, .sql(.default(0)))
            .field("last_failed_sign_in", .datetime)
            .field("last_sign_in_at", .datetime)
            .field("account_locked", .bool, .required, .sql(.default(false)))
            .field("lockout_until", .datetime)
            .field("require_password_change", .bool, .required, .sql(.default(false)))
            .field("totp_mfa_enabled", .bool, .required, .sql(.default(false)))
            .field("totp_mfa_secret", .string)
            .field("email_mfa_enabled", .bool, .required, .sql(.default(false)))
            .field("token_version", .int, .required, .sql(.default(0)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "username")
            .unique(on: "email")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("user").delete()
    }
} 
