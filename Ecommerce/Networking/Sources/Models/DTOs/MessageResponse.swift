import Foundation

/// Simple message response structure
public struct MessageResponse: Codable, Sendable {
    public let message: String
    public let success: Bool
    
    public init(message: String, success: Bool) {
        self.message = message
        self.success = success
    }
} 