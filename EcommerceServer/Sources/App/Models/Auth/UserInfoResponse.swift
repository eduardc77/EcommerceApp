import Foundation
import Hummingbird

/// OpenID Connect UserInfo Response
/// This follows the standard claims specified in OpenID Connect Core 1.0
/// https://openid.net/specs/openid-connect-core-1_0.html#StandardClaims
struct UserInfoResponse: Codable, ResponseEncodable {
    // Standard OIDC claims
    let sub: String          // Subject - Identifier for the user (required)
    let name: String?        // Full name
    let email: String?       // Email address
    let emailVerified: Bool? // Email verification status
    let picture: String?     // Profile picture URL
    let updatedAt: Int?      // Time when the user's information was last updated (Unix timestamp)
    
    // Non-standard claims
    let role: String?        // User's role
    
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
    
    /// Create a UserInfo response from a User model
    init(from user: User) {
        self.sub = user.id?.uuidString ?? ""
        self.name = user.displayName
        self.email = user.email
        self.emailVerified = user.emailVerified
        self.picture = user.profilePicture
        self.updatedAt = user.updatedAt?.timeIntervalSince1970.rounded().intValue
        self.role = user.role.rawValue
    }
}

private extension Double {
    var intValue: Int {
        return Int(self)
    }
} 