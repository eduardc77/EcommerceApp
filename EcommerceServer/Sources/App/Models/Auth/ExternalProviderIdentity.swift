import Foundation
import FluentKit

/// Model for storing links between users and their external provider identities (Google, Apple, etc.)
final class ExternalProviderIdentity: Model, @unchecked Sendable {
    static let schema = "external_provider_identities"
    
    /// Enumeration of supported provider types
    enum Provider: String, Codable {
        case google
        case apple
    }
    
    /// Unique identifier
    @ID(key: .id)
    var id: UUID?
    
    /// Reference to the user
    @Parent(key: "user_id")
    var user: User
    
    /// External provider name (e.g., "google", "apple")
    @Field(key: "provider")
    var provider: String
    
    /// User ID from the external provider
    @Field(key: "provider_user_id")
    var providerUserId: String
    
    /// Created at timestamp
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// Updated at timestamp
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Default initializer
    init() {}
    
    /// Initialize with values
    init(id: UUID? = nil, userId: UUID, provider: String, providerUserId: String) {
        self.id = id
        self.$user.id = userId
        self.provider = provider
        self.providerUserId = providerUserId
    }
}

// MARK: - Migration
extension ExternalProviderIdentity {
    struct Migration: AsyncMigration {
        /// Prepare the database schema
        func prepare(on database: Database) async throws {
            try await database.schema(ExternalProviderIdentity.schema)
                .id()
                .field("user_id", .uuid, .required, .references(User.schema, "id", onDelete: .cascade))
                .field("provider", .string, .required)
                .field("provider_user_id", .string, .required)
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .unique(on: "provider", "provider_user_id")
                .create()
        }
        
        /// Revert the database schema
        func revert(on database: Database) async throws {
            try await database.schema(ExternalProviderIdentity.schema).delete()
        }
    }
} 
