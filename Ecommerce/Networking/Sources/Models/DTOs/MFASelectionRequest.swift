/// Request for selecting an MFA method during sign in
public struct MFASelectionRequest: Codable, Sendable {
    public let method: String
    
    public init(method: String) {
        self.method = method
    }
} 