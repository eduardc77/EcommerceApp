import Foundation
import FluentKit
import Crypto
import CryptoKit

/// Authorization code for OAuth 2.0 Authorization Code flow
final class AuthorizationCode: Model, @unchecked Sendable {
    static let schema = "authorization_codes"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "client_id")
    var clientId: String
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "redirect_uri")
    var redirectURI: String
    
    @Field(key: "scopes")
    var scopes: [String]
    
    @Field(key: "code_challenge")
    var codeChallenge: String?
    
    @Field(key: "code_challenge_method")
    var codeChallengeMethod: String?
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    @Field(key: "is_used")
    var isUsed: Bool
    
    @Field(key: "state")
    var state: String?
    
    @Field(key: "nonce")
    var nonce: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    init() { }
    
    init(
        id: UUID? = nil,
        code: String,
        clientId: String,
        userId: User.IDValue,
        redirectURI: String,
        scopes: [String],
        codeChallenge: String? = nil,
        codeChallengeMethod: String? = nil,
        expiresAt: Date,
        isUsed: Bool = false,
        state: String? = nil,
        nonce: String? = nil
    ) {
        self.id = id
        self.code = code
        self.clientId = clientId
        self.$user.id = userId
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.codeChallenge = codeChallenge
        self.codeChallengeMethod = codeChallengeMethod
        self.expiresAt = expiresAt
        self.isUsed = isUsed
        self.state = state
        self.nonce = nonce
    }
    
    /// Generate a random authorization code
    static func generateCode() -> String {
        var randomBytes = [UInt8](repeating: 0, count: 32)
        _ = randomBytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        return Data(randomBytes).base64URLEncodedString()
    }
    
    /// Check if the authorization code is expired
    var isExpired: Bool {
        return Date() > expiresAt
    }
    
    /// Verify the PKCE code verifier against the stored code challenge
    /// - Parameter codeVerifier: The code verifier to verify
    /// - Returns: True if the code verifier is valid
    func verifyCodeVerifier(_ codeVerifier: String) -> Bool {
        guard let challenge = codeChallenge else {
            return false
        }
        
        let method = codeChallengeMethod ?? "plain"
        
        switch method {
        case "S256":
            let verifierData = Data(codeVerifier.utf8)
            let hash = SHA256.hash(data: verifierData)
            let computedChallenge = Data(hash).base64URLEncodedString()
            return challenge == computedChallenge
            
        case "plain":
            return challenge == codeVerifier
            
        default:
            return false
        }
    }
}

extension AuthorizationCode {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(AuthorizationCode.schema)
                .id()
                .field("code", .string, .required)
                .field("client_id", .string, .required)
                .field("user_id", .uuid, .required, .references("user", "id", onDelete: .cascade))
                .field("redirect_uri", .string, .required)
                .field("scopes", .array(of: .string), .required)
                .field("code_challenge", .string)
                .field("code_challenge_method", .string)
                .field("expires_at", .datetime, .required)
                .field("is_used", .bool, .required, .sql(.default(false)))
                .field("state", .string)
                .field("nonce", .string)
                .field("created_at", .datetime)
                .unique(on: "code")
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(AuthorizationCode.schema).delete()
        }
    }
} 