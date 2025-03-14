import Foundation

public protocol OAuthToken: Codable, Sendable {
    var accessToken: String { get }
    var refreshToken: String { get }
    var tokenType: String { get }
    var expiresIn: UInt { get }
    var expiresAt: String { get }
    var expirationDate: Date? { get }
    var isAccessTokenValid: Bool { get }
}

public struct Token: OAuthToken {
    public let accessToken: String
    public let refreshToken: String
    public let tokenType: String
    public let expiresIn: UInt
    public let expiresAt: String
    
    public var expirationDate: Date? {
        ISO8601DateFormatter().date(from: expiresAt)
    }
    
    public var isAccessTokenValid: Bool {
        guard let expirationDate = expirationDate else {
            return false // If we can't parse the date, consider token invalid
        }
        // Add 5 second buffer to prevent edge cases
        return expirationDate.addingTimeInterval(-5) > Date()
    }
    
    public init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: UInt,
        expiresAt: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
    }
}
