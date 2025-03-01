public struct AvailabilityResponse: Codable, Sendable {
    public let available: Bool
    public let identifier: String
    public let type: String
    
    public init(available: Bool, identifier: String, type: String) {
        self.available = available
        self.identifier = identifier
        self.type = type
    }
} 