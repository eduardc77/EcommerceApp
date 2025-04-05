import Foundation

public struct RecoveryMFAStatusResponse: Codable, Sendable {
    public let enabled: Bool
    public let hasValidCodes: Bool
    
    public init(enabled: Bool, hasValidCodes: Bool) {
        self.enabled = enabled
        self.hasValidCodes = hasValidCodes
    }
} 