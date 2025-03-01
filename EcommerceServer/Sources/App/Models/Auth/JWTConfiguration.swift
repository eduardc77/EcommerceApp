import Foundation
import Hummingbird

struct JWTConfiguration {
    let accessTokenExpiration: TimeInterval
    let refreshTokenExpiration: TimeInterval
    let issuer: String
    let audience: String
    let minimumPasswordLength: Int
    let maximumPasswordLength: Int
    let maxRefreshTokens: Int
    let maxFailedAttempts: Int
    let lockoutDuration: TimeInterval
    
    static func load() -> JWTConfiguration {
        // Default values as TimeInterval (which is just a typealias for Double)
        let defaultAccessExpiration: TimeInterval = 900  // 15 minutes
        let defaultRefreshExpiration: TimeInterval = 604800  // 7 days
        let defaultLockoutDuration: TimeInterval = 900  // 15 minutes
        
        // Get environment variables with defaults
        let accessExpirationStr = Environment.get("JWT_ACCESS_TOKEN_EXPIRATION", default: "900")
        let refreshExpirationStr = Environment.get("JWT_REFRESH_TOKEN_EXPIRATION", default: "604800")
        let lockoutDurationStr = Environment.get("LOCKOUT_DURATION", default: "900")
        
        // Convert to TimeInterval, falling back to defaults if conversion fails
        let accessExpiration = TimeInterval(accessExpirationStr) ?? defaultAccessExpiration
        let refreshExpiration = TimeInterval(refreshExpirationStr) ?? defaultRefreshExpiration
        let lockoutDuration = TimeInterval(lockoutDurationStr) ?? defaultLockoutDuration
        
        // Get string values with defaults
        let issuer = Environment.get("JWT_ISSUER", default: "com.ecommerce.api")
        let audience = Environment.get("JWT_AUDIENCE", default: "com.ecommerce.client")
        
        // Get integer values with defaults - NIST recommended password requirements
        let minPasswordLength = Environment.getInt("MIN_PASSWORD_LENGTH", default: 8)  // NIST minimum
        let maxPasswordLength = Environment.getInt("MAX_PASSWORD_LENGTH", default: 64) // NIST recommended max
        let maxRefreshTokens = Environment.getInt("MAX_REFRESH_TOKENS", default: 5)
        let maxFailedAttempts = Environment.getInt("MAX_FAILED_ATTEMPTS", default: 5)
        
        return JWTConfiguration(
            accessTokenExpiration: accessExpiration,
            refreshTokenExpiration: refreshExpiration,
            issuer: issuer,
            audience: audience,
            minimumPasswordLength: minPasswordLength,
            maximumPasswordLength: maxPasswordLength,
            maxRefreshTokens: maxRefreshTokens,
            maxFailedAttempts: maxFailedAttempts,
            lockoutDuration: lockoutDuration
        )
    }
} 
