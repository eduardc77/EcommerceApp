import Foundation
import JWTKit

/// JWT payload data structure
struct JWTPayloadData: JWTPayload {
    let subject: SubjectClaim
    let expiration: ExpirationClaim
    let type: String
    let issuer: String
    let audience: String
    let issuedAt: Date
    let id: String
    let role: String
    let tokenVersion: Int?
    
    // OAuth and OpenID Connect specific claims
    let scope: String?
    let clientId: String?
    let nonce: String?
    
    enum CodingKeys: String, CodingKey {
        case subject = "sub"
        case expiration = "exp"
        case type = "type"
        case issuer = "iss"
        case audience = "aud"
        case issuedAt = "iat"
        case id = "jti"
        case role = "role"
        case tokenVersion = "tv"
        case scope
        case clientId = "client_id"
        case nonce
    }
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
    
    /// Initialize with all fields
    init(
        subject: SubjectClaim,
        expiration: ExpirationClaim,
        type: String,
        issuer: String,
        audience: String,
        issuedAt: Date,
        id: String,
        role: String,
        tokenVersion: Int?,
        scope: String? = nil,
        clientId: String? = nil,
        nonce: String? = nil
    ) {
        self.subject = subject
        self.expiration = expiration
        self.type = type
        self.issuer = issuer
        self.audience = audience
        self.issuedAt = issuedAt
        self.id = id
        self.role = role
        self.tokenVersion = tokenVersion
        self.scope = scope
        self.clientId = clientId
        self.nonce = nonce
    }
} 
