import Foundation
import FluentKit
import Hummingbird
import HTTPTypes

/// Database model for storing active user sessions
final class Session: Model, @unchecked Sendable {
    static let schema = "sessions"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "device_name")
    var deviceName: String
    
    @Field(key: "ip_address")
    var ipAddress: String
    
    @Field(key: "user_agent")
    var userAgent: String
    
    @Field(key: "token_id")
    var tokenId: String
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Field(key: "created_at")
    var createdAt: Date
    
    @Field(key: "last_used_at")
    var lastUsedAt: Date
    
    init() { }
    
    init(
        id: UUID? = nil,
        userID: User.IDValue,
        deviceName: String,
        ipAddress: String,
        userAgent: String,
        tokenId: String,
        isActive: Bool = true
    ) {
        self.id = id
        self.$user.id = userID
        self.deviceName = deviceName
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.tokenId = tokenId
        self.isActive = isActive
        self.createdAt = Date()
        self.lastUsedAt = Date()
    }
    
    /// Factory method to create a session with consistent defaults
    static func create(
        userID: UUID,
        request: Request,
        tokenID: String
    ) -> Session {
        // Extract device info from request
        let deviceName: String
        let userAgent: String
        
        if let deviceNameHeader = HTTPField.Name("X-Device-Name") {
            deviceName = request.headers[deviceNameHeader] ?? "Unknown Device"
        } else {
            deviceName = "Unknown Device"
        }
        
        if let userAgentHeader = HTTPField.Name("User-Agent") {
            userAgent = request.headers[userAgentHeader] ?? "Unknown"
        } else {
            userAgent = "Unknown"
        }
        
        // Get IP address with fallback
        var ipAddress = "127.0.0.1"
        if let forwardedForName = HTTPField.Name("X-Forwarded-For"),
           let forwardedFor = request.headers[forwardedForName]?.split(separator: ",").first {
            ipAddress = String(forwardedFor).trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let realIPName = HTTPField.Name("X-Real-IP"),
                  let realIP = request.headers[realIPName] {
            ipAddress = String(realIP)
        }
        
        return Session(
            id: UUID(),
            userID: userID,
            deviceName: deviceName,
            ipAddress: ipAddress,
            userAgent: userAgent,
            tokenId: tokenID
        )
    }
}

extension Session {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema("sessions")
                .id()
                .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
                .field("device_name", .string, .required)
                .field("ip_address", .string, .required)
                .field("user_agent", .string, .required)
                .field("token_id", .string, .required)
                .field("is_active", .bool, .required, .sql(.default(true)))
                .field("created_at", .datetime, .required)
                .field("last_used_at", .datetime, .required)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema("sessions").delete()
        }
    }
}

// MARK: - Response Structures
/// Individual session response
struct SessionResponse: Codable, ResponseEncodable {
    let id: String
    let deviceName: String
    let ipAddress: String
    let userAgent: String
    let createdAt: String
    let lastUsedAt: String
    let isCurrent: Bool
    
    init(from session: Session, currentTokenId: String?) {
        self.id = session.id?.uuidString ?? "unknown"
        self.deviceName = session.deviceName
        self.ipAddress = session.ipAddress
        self.userAgent = session.userAgent
        self.createdAt = session.createdAt.ISO8601Format()
        self.lastUsedAt = session.lastUsedAt.ISO8601Format()
        self.isCurrent = session.tokenId == currentTokenId
    }
}

/// List of sessions response
struct SessionListResponse: Codable, ResponseEncodable {
    let sessions: [SessionResponse]
    let currentSessionId: String?
}
