import Foundation

/// Response for successful login containing JWT token and user info
public struct AuthResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: UInt      // Seconds until expiration
    public let expiresAt: String    // ISO8601 date string
    public let user: UserResponse
    public let requiresTOTP: Bool
    public let requiresEmailVerification: Bool
    
    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: UInt,
        expiresAt: String,
        user: UserResponse,
        requiresTOTP: Bool = false,
        requiresEmailVerification: Bool = false
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
        self.user = user
        self.requiresTOTP = requiresTOTP
        self.requiresEmailVerification = requiresEmailVerification
    }
    
    /// Helper to get expiration date from ISO8601 string
    public var expirationDate: Date? {
        ISO8601DateFormatter().date(from: expiresAt)
    }
} 