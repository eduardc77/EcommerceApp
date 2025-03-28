import Foundation
import Hummingbird

/// OpenID Connect Configuration
/// Follows the specification at https://openid.net/specs/openid-connect-discovery-1_0.html
public struct OIDCConfiguration: Codable, ResponseEncodable {
    // Required fields
    let issuer: String
    let authorizationEndpoint: String?
    let tokenEndpoint: String?
    let jwksUri: String
    let responseTypesSupported: [String]
    let subjectTypesSupported: [String]
    let idTokenSigningAlgValuesSupported: [String]
    
    // Optional fields
    let userInfoEndpoint: String?
    let registrationEndpoint: String?
    let scopesSupported: [String]?
    let claimsSupported: [String]?
    let grantTypesSupported: [String]?
    
    enum CodingKeys: String, CodingKey {
        case issuer
        case authorizationEndpoint = "authorization_endpoint"
        case tokenEndpoint = "token_endpoint"
        case jwksUri = "jwks_uri"
        case userInfoEndpoint = "userinfo_endpoint"
        case registrationEndpoint = "registration_endpoint"
        case responseTypesSupported = "response_types_supported"
        case subjectTypesSupported = "subject_types_supported"
        case idTokenSigningAlgValuesSupported = "id_token_signing_alg_values_supported"
        case scopesSupported = "scopes_supported"
        case claimsSupported = "claims_supported"
        case grantTypesSupported = "grant_types_supported"
    }
    
    /// Create default configuration for the application
    static func defaultConfiguration(baseUrl: String) -> OIDCConfiguration {
        // Base URL example: https://api.ecommerce.com or http://localhost:8080
        return OIDCConfiguration(
            issuer: baseUrl,
            authorizationEndpoint: nil, // Not yet implemented
            tokenEndpoint: nil,          // Not yet implemented
            jwksUri: "\(baseUrl)/.well-known/jwks.json",
            responseTypesSupported: ["id_token"],
            subjectTypesSupported: ["public"],
            idTokenSigningAlgValuesSupported: ["HS256"],
            userInfoEndpoint: "\(baseUrl)/api/v1/auth/userinfo", // User info endpoint
            registrationEndpoint: nil,
            scopesSupported: ["openid", "profile", "email"],
            claimsSupported: ["sub", "iss", "name", "email", "role", "email_verified", "picture", "updated_at"],
            grantTypesSupported: nil
        )
    }
} 