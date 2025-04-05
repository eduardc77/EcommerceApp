public struct MFAVerifyResponse: Codable, Sendable {
    public let message: String
    public let success: Bool
    public let recoveryCodes: [String]?
    
    public init(message: String, success: Bool, recoveryCodes: [String]? = nil) {
        self.message = message
        self.success = success
        self.recoveryCodes = recoveryCodes
    }
} 
