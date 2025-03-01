import Foundation

public protocol OAuthToken: Codable, Sendable {
    var accessToken: String { get }
    var refreshToken: String { get }
    var expirationDate: Date? { get }
    var isAccessTokenValid: Bool { get }
}

public struct Token: OAuthToken {
    public let accessToken: String
    public let refreshToken: String
    public let expirationDate: Date?
    
    public var isAccessTokenValid: Bool {
        guard let expirationDate = expirationDate else {
            return true // If no expiration date, assume valid
        }
        return expirationDate > Date()
    }
    
    public init(
        accessToken: String,
        refreshToken: String,
        expirationDate: Date?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expirationDate = expirationDate
    }
}
