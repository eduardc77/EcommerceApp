import Foundation

public struct AuthResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let expiresIn: Int      // Seconds until expiration (for UI)
    public let expiresAt: String   // ISO8601 date (for validation)
    public let user: UserResponse
    
    public init(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int,
        expiresAt: String,
        user: UserResponse
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
        self.user = user
    }
} 