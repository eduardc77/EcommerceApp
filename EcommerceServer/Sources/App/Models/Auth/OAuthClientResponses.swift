import Foundation
import Hummingbird
import FluentKit

/// Response structure for OAuth client
struct OAuthClientResponse: Codable, ResponseEncodable {
    let id: UUID
    let clientId: String
    let name: String
    let redirectURIs: [String]
    let allowedGrantTypes: [String]
    let allowedScopes: [String]
    let isPublic: Bool
    let isActive: Bool
    let description: String?
    let websiteURL: String?
    let logoURL: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    init(from client: OAuthClient) {
        self.id = client.id!
        self.clientId = client.clientId
        self.name = client.name
        self.redirectURIs = client.redirectURIs
        self.allowedGrantTypes = client.allowedGrantTypes
        self.allowedScopes = client.allowedScopes
        self.isPublic = client.isPublic
        self.isActive = client.isActive
        self.description = client.description
        self.websiteURL = client.websiteURL
        self.logoURL = client.logoURL
        self.createdAt = client.createdAt
        self.updatedAt = client.updatedAt
    }
}

/// Response structure for listing OAuth clients
struct OAuthClientListResponse: Codable, ResponseEncodable {
    let clients: [OAuthClientResponse]
    let count: Int
}

/// Request structure for creating a new OAuth client
struct CreateOAuthClientRequest: Codable {
    let name: String
    let redirectURIs: [String]
    let allowedGrantTypes: [String]
    let allowedScopes: [String]
    let isPublic: Bool?
    let description: String?
    let websiteURL: String?
    let logoURL: String?
} 