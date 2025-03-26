import Foundation
import FluentKit
import Logging

struct TokenRotationService {
    private let db: Database
    private let logger: Logger
    private let tokenStore: TokenStoreProtocol
    
    // Maximum allowed rotations for a token family
    private let maxGenerations = 100
    
    init(db: Database, tokenStore: TokenStoreProtocol, logger: Logger) {
        self.db = db
        self.tokenStore = tokenStore
        self.logger = logger
    }
    
    /// Checks if a refresh token is valid for rotation
    /// - Parameter jti: JWT ID of the token
    /// - Returns: Bool indicating if the token can be rotated
    func isValidForRotation(jti: String) async throws -> Bool {
        // Find token record by jti
        guard let token = try await Token.query(on: db)
            .filter(\.$jti == jti)
            .first() else {
            logger.warning("Token not found in DB with JTI: \(jti)")
            return false
        }
        
        // Check if token is already revoked
        if token.isRevoked {
            logger.info("Token with JTI \(jti) is already revoked")
            return false
        }
        
        // Check generation limit
        if token.generation >= maxGenerations {
            logger.warning("Token family \(token.familyId) reached max generations (\(maxGenerations))")
            return false
        }
        
        // Check for token reuse by looking for child tokens
        let hasChildren = try await Token.query(on: db)
            .filter(\.$parentJti == jti)
            .count() > 0
            
        if hasChildren {
            // This token has already been rotated - possible token reuse attack
            logger.warning("Potential token reuse detected for JTI: \(jti)")
            
            // Revoke the entire token family
            try await revokeTokenFamily(familyId: token.familyId)
            return false
        }
        
        return true
    }
    
    /// Rotate a refresh token to a new generation
    /// - Parameters:
    ///   - oldJti: JWT ID of the token being rotated
    ///   - newJti: JWT ID for the new token
    ///   - refreshToken: The new refresh token string
    ///   - expiresAt: Expiration date for the new token
    /// - Returns: Bool indicating success
    func rotateToken(
        oldJti: String,
        newJti: String,
        refreshToken: String,
        expiresAt: Date
    ) async throws -> Bool {
        // Find the existing token
        guard let oldToken = try await Token.query(on: db)
            .filter(\.$jti == oldJti)
            .first() else {
            logger.warning("Cannot rotate - original token not found: \(oldJti)")
            return false
        }
        
        // Mark old token as revoked
        oldToken.isRevoked = true
        try await oldToken.save(on: db)
        
        // Blacklist old access token
        await tokenStore.blacklist(
            oldToken.accessToken,
            expiresAt: oldToken.accessTokenExpiresAt,
            reason: .tokenVersionChange
        )
        logger.info("Blacklisted old access token during rotation")
        
        // Create updated token record with incremented generation
        try await Token.query(on: db)
            .filter(\.$jti == newJti)
            .set(\.$parentJti, to: oldJti)
            .set(\.$familyId, to: oldToken.familyId)
            .set(\.$generation, to: oldToken.generation + 1)
            .update()
        
        logger.info("Rotated token \(oldJti) to \(newJti) (family: \(oldToken.familyId), generation: \(oldToken.generation + 1))")
        
        return true
    }
    
    /// Revoke an entire token family
    /// - Parameter familyId: The ID of the token family to revoke
    func revokeTokenFamily(familyId: UUID) async throws {
        // Mark all tokens in family as revoked
        try await Token.query(on: db)
            .filter(\.$familyId == familyId)
            .set(\.$isRevoked, to: true)
            .update()
        
        logger.warning("Revoked entire token family: \(familyId)")
        
        // Find and blacklist any active refresh tokens
        let tokens = try await Token.query(on: db)
            .filter(\.$familyId == familyId)
            .filter(\.$refreshToken != nil)
            .all()
        
        for token in tokens {
            if let refreshToken = token.refreshToken {
                await tokenStore.blacklist(
                    refreshToken,
                    expiresAt: token.refreshTokenExpiresAt,
                    reason: .tokenVersionChange
                )
            }
        }
    }
} 
