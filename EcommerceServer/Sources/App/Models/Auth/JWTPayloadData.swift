import Foundation
import JWTKit
import NIOFoundationCompat

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
    }
    
    func verify(using algorithm: some JWTAlgorithm) async throws {
        try self.expiration.verifyNotExpired()
    }
} 
