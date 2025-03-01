import Foundation

public struct ServerError: Error, Codable, Equatable {
    public let error: String
    public let timestamp: Date
    public let path: String
    public let status: Int
}
