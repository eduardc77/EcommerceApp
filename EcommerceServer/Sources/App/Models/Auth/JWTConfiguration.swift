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
    let jwtSecretMinLength: Int = 32  // Minimum 256 bits for HMAC
    
    static func load() -> JWTConfiguration {
        // Check environment
        let environment = Environment.get("ENV", default: "development")
        let isProduction = environment == "production"
        
        // Default values as TimeInterval
        let defaultAccessExpiration: TimeInterval = 900  // 15 minutes
        let defaultRefreshExpiration: TimeInterval = 86400  // 24 hours
        let defaultLockoutDuration: TimeInterval = 900  // 15 minutes
        
        // Get environment variables with defaults
        let accessExpirationStr = Environment.get("JWT_ACCESS_TOKEN_EXPIRATION", default: "900")
        let refreshExpirationStr = Environment.get("JWT_REFRESH_TOKEN_EXPIRATION", default: "86400")
        let lockoutDurationStr = Environment.get("LOCKOUT_DURATION", default: "900")
        
        // Convert to TimeInterval, falling back to defaults if conversion fails
        let accessExpiration = TimeInterval(accessExpirationStr) ?? defaultAccessExpiration
        let refreshExpiration = TimeInterval(refreshExpirationStr) ?? defaultRefreshExpiration
        let lockoutDuration = TimeInterval(lockoutDurationStr) ?? defaultLockoutDuration
        
        // Get JWT secret with development fallback
        let jwtSecret = Environment.get("JWT_SECRET", default: isProduction ? "" : "development_secret_key_do_not_use_in_production")
        if isProduction {
            guard !jwtSecret.isEmpty else {
                fatalError("JWT_SECRET environment variable must be set in production")
            }
            guard jwtSecret.count >= 32 else {
                fatalError("JWT_SECRET must be at least 32 characters long in production")
            }
        } else {
            if jwtSecret == "development_secret_key_do_not_use_in_production" {
                print("⚠️ WARNING: Using default development JWT secret")
                print("⚠️ WARNING: This is only acceptable for development/testing")
            } else if jwtSecret.count < 32 {
                print("⚠️ WARNING: JWT_SECRET is shorter than recommended length of 32 characters")
            }
        }
        
        // Get string values with defaults
        let issuer = Environment.get("JWT_ISSUER", default: "com.ecommerce.api")
        let audience = Environment.get("JWT_AUDIENCE", default: "com.ecommerce.client")
        
        // Get integer values with defaults - NIST recommended password requirements
        let minPasswordLength = Environment.getInt("MIN_PASSWORD_LENGTH", default: 12)
        let maxPasswordLength = Environment.getInt("MAX_PASSWORD_LENGTH", default: 128)
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
