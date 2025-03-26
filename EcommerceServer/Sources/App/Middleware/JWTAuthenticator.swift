import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import JWTKit

/// JWT authenticator with blacklist support
struct JWTAuthenticator: AuthenticatorMiddleware, @unchecked Sendable {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection
    let fluent: Fluent
    private let tokenStore: TokenStoreProtocol
    
    init(fluent: Fluent, tokenStore: TokenStoreProtocol) {
        self.jwtKeyCollection = JWTKeyCollection()
        self.fluent = fluent
        self.tokenStore = tokenStore
    }
    
    init(keyCollection: JWTKeyCollection, fluent: Fluent, tokenStore: TokenStoreProtocol) {
        self.jwtKeyCollection = keyCollection
        self.fluent = fluent
        self.tokenStore = tokenStore
    }
    
    init(jwksData: ByteBuffer, fluent: Fluent, tokenStore: TokenStoreProtocol) async throws {
        let jwks = try JSONDecoder().decode(JWKS.self, from: jwksData)
        self.jwtKeyCollection = JWTKeyCollection()
        try await self.jwtKeyCollection.add(jwks: jwks)
        self.fluent = fluent
        self.tokenStore = tokenStore
    }
    
    func useSigner(hmac: HMACKey, digestAlgorithm: DigestAlgorithm, kid: JWKIdentifier? = nil) async {
        await self.jwtKeyCollection.add(hmac: hmac, digestAlgorithm: digestAlgorithm, kid: kid)
    }
    
    func authenticate(request: Request, context: Context) async throws -> User? {
        // get JWT from bearer authorization
        guard let jwtToken = request.headers.bearer?.token else { throw HTTPError(.unauthorized) }
        
        // Check if token is blacklisted
        if await tokenStore.isBlacklisted(jwtToken) {
            throw HTTPError(.unauthorized, message: "Token has been revoked")
        }
        
        let payload: JWTPayloadData
        do {
            payload = try await self.jwtKeyCollection.verify(jwtToken, as: JWTPayloadData.self)
        } catch let error as JWTError {
            switch error.errorType {
            case .claimVerificationFailure:
                throw HTTPError(.unauthorized, message: "Token has expired")
            case .signatureVerificationFailed:
                throw HTTPError(.unauthorized, message: "Invalid token signature")
            default:
                context.logger.debug("couldn't verify token")
                throw HTTPError(.unauthorized, message: "Invalid token")
            }
        }
        
        let db = self.fluent.db()
        
        // Try to parse the subject as a UUID
        guard let userID = UUID(uuidString: payload.subject.value) else {
            context.logger.debug("invalid subject format")
            throw HTTPError(.unauthorized)
        }
        
        // Look up user by ID
        if let existingUser = try await User.find(userID, on: db) {
            // Verify token version matches user's current version
            guard let tokenVersion = payload.tokenVersion else {
                context.logger.debug("missing token version")
                throw HTTPError(.unauthorized, message: "Invalid token format")
            }
            
            // Check if token version matches
            guard tokenVersion == existingUser.tokenVersion else {
                context.logger.debug("token version mismatch: token=\(tokenVersion) user=\(existingUser.tokenVersion)")
                // Blacklist this token since it's using an old version
                await tokenStore.blacklist(jwtToken, expiresAt: payload.expiration.value, reason: .tokenVersionChange)
                throw HTTPError(.unauthorized, message: "Token has been invalidated due to security changes")
            }
            
            // Check if token type is valid
            guard payload.type == "access" else {
                context.logger.debug("invalid token type")
                throw HTTPError(.unauthorized, message: "Invalid token type")
            }
            
            // Verify issuer and audience
            let config = JWTConfiguration.load()
            guard payload.issuer == config.issuer,
                  payload.audience == config.audience else {
                context.logger.debug("invalid issuer or audience")
                throw HTTPError(.unauthorized, message: "Invalid token claims")
            }
            
            return existingUser
        }
        
        // If user doesn't exist, this is an invalid token
        throw HTTPError(.unauthorized)
    }
} 
