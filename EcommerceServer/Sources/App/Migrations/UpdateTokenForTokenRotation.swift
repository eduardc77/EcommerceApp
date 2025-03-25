import FluentKit
import SQLKit

struct UpdateTokenForTokenRotation: AsyncMigration {
    func prepare(on database: Database) async throws {
        // Check if the tokens table exists
        if let sql = database as? SQLDatabase {
            // First check if the table exists
            let tableExists = try await sql.raw("SELECT name FROM sqlite_master WHERE type='table' AND name='tokens'").all().count > 0
            
            if tableExists {
                // Only populate existing tokens with default values if the table exists
                // Using SQL directly as Fluent doesn't have a good API for updates with expressions
                try await sql.raw("UPDATE tokens SET jti = access_token, family_id = id, generation = 0, is_revoked = false WHERE jti IS NULL").run()
                
                // Note: we don't need to add the columns since they're already defined in Token.Migration
            } else {
                // If the tokens table doesn't exist yet, that's fine - the Token.Migration will create it
                // with all the necessary fields
            }
        }
    }
    
    func revert(on database: Database) async throws {
        // No need to revert anything, since we're only populating existing records
        // and not making schema changes
    }
} 