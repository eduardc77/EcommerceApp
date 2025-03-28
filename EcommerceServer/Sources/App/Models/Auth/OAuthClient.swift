import Foundation
import FluentKit
import Crypto

/// OAuth 2.0 Client entity
final class OAuthClient: Model, @unchecked Sendable {
    static let schema = "oauth_clients"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "client_id")
    var clientId: String
    
    @Field(key: "client_secret")
    var clientSecret: String?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "redirect_uris")
    var redirectURIs: [String]
    
    @Field(key: "allowed_grant_types")
    var allowedGrantTypes: [String]
    
    @Field(key: "allowed_scopes")
    var allowedScopes: [String]
    
    @Field(key: "is_public")
    var isPublic: Bool
    
    @Field(key: "is_active")
    var isActive: Bool
    
    @Field(key: "description")
    var description: String?
    
    @Field(key: "website_url")
    var websiteURL: String?
    
    @Field(key: "logo_url")
    var logoURL: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        clientId: String,
        clientSecret: String? = nil,
        name: String,
        redirectURIs: [String],
        allowedGrantTypes: [String],
        allowedScopes: [String],
        isPublic: Bool = false,
        isActive: Bool = true,
        description: String? = nil,
        websiteURL: String? = nil,
        logoURL: String? = nil
    ) {
        self.id = id
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.name = name
        self.redirectURIs = redirectURIs
        self.allowedGrantTypes = allowedGrantTypes
        self.allowedScopes = allowedScopes
        self.isPublic = isPublic
        self.isActive = isActive
        self.description = description
        self.websiteURL = websiteURL
        self.logoURL = logoURL
    }
    
    /// Validate a redirect URI against the allowed list
    /// - Parameter redirectURI: The redirect URI to validate
    /// - Returns: True if the redirect URI is allowed
    func validateRedirectURI(_ redirectURI: String) -> Bool {
        return redirectURIs.contains { 
            // Exact match
            if $0 == redirectURI {
                return true
            }
            
            // Pattern match with wildcard
            if $0.hasSuffix("*") {
                let prefix = $0.dropLast()
                return redirectURI.hasPrefix(prefix)
            }
            
            return false
        }
    }
    
    /// Generate client credentials (ID and secret)
    /// - Returns: A tuple with clientId and clientSecret
    static func generateCredentials() -> (clientId: String, clientSecret: String) {
        let clientId = UUID().uuidString
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = randomBytes.withUnsafeMutableBytes { 
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        let clientSecret = Data(randomBytes).base64URLEncodedString()
        return (clientId, clientSecret)
    }
}

extension OAuthClient {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(OAuthClient.schema)
                .id()
                .field("client_id", .string, .required)
                .field("client_secret", .string)
                .field("name", .string, .required)
                .field("redirect_uris", .array(of: .string), .required)
                .field("allowed_grant_types", .array(of: .string), .required)
                .field("allowed_scopes", .array(of: .string), .required)
                .field("is_public", .bool, .required, .sql(.default(false)))
                .field("is_active", .bool, .required, .sql(.default(true)))
                .field("description", .string)
                .field("website_url", .string)
                .field("logo_url", .string)
                .field("created_at", .datetime)
                .field("updated_at", .datetime)
                .unique(on: "client_id")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(OAuthClient.schema).delete()
        }
    }
} 