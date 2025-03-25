import Foundation
import FluentKit

final class Token: Model {
    static let schema = "tokens"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "access_token")
    var accessToken: String
    
    @Field(key: "refresh_token")
    var refreshToken: String?
    
    @Field(key: "access_token_expires_at")
    var accessTokenExpiresAt: Date
    
    @Field(key: "refresh_token_expires_at")
    var refreshTokenExpiresAt: Date
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "last_used_at")
    var lastUsedAt: Date
    
    @Parent(key: "session_id")
    var session: Session
    
    init() { }
    
    init(
        id: UUID? = nil,
        accessToken: String,
        refreshToken: String? = nil,
        accessTokenExpiresAt: Date,
        refreshTokenExpiresAt: Date,
        sessionId: Session.IDValue
    ) {
        self.id = id
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.createdAt = Date()
        self.lastUsedAt = Date()
        self.$session.id = sessionId
    }
}

extension Token {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema("tokens")
                .id()
                .field("access_token", .string, .required)
                .field("refresh_token", .string)
                .field("access_token_expires_at", .datetime, .required)
                .field("refresh_token_expires_at", .datetime, .required)
                .field("created_at", .datetime, .required)
                .field("last_used_at", .datetime, .required)
                .field("session_id", .uuid, .required, .references("sessions", "id", onDelete: .cascade))
                .unique(on: "access_token")
                .unique(on: "refresh_token")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema("tokens").delete()
        }
    }
} 