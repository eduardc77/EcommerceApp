import Foundation

/// OpenID Connect UserInfo Response
/// This follows the standard claims specified in OpenID Connect Core 1.0
/// https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims
public struct UserInfoResponse: Codable, Sendable {
    // Standard OIDC claims
    public let sub: String          // Subject - Identifier for the user (required)
    public let name: String?        // Full name
    public let email: String?       // Email address
    public let emailVerified: Bool? // Email verification status
    public let picture: String?     // Profile picture URL
    public let updatedAt: Int?      // Time when the user's information was last updated (Unix timestamp)
    
    // Non-standard claims
    public let role: String?        // User's role
    
    // Custom coding keys to match OpenID Connect standard names
    enum CodingKeys: String, CodingKey {
        case sub
        case name
        case email
        case emailVerified = "email_verified"
        case picture
        case updatedAt = "updated_at"
        case role
    }
    
    public init(
        sub: String,
        name: String?,
        email: String?,
        emailVerified: Bool?,
        picture: String?,
        updatedAt: Int?,
        role: String?
    ) {
        self.sub = sub
        self.name = name
        self.email = email
        self.emailVerified = emailVerified
        self.picture = picture
        self.updatedAt = updatedAt
        self.role = role
    }
}

// MARK: - Preview Data
extension UserInfoResponse {
    static let previewUser = UserInfoResponse(
        sub: UUID().uuidString,
        name: "John Appleseed",
        email: "appleseed@icloud.com",
        emailVerified: true,
        picture: "https://api.dicebear.com/7.x/avataaars/png",
        updatedAt: 1700000000,
        role: "customer"
    )
} 
