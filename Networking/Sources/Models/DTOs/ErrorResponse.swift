/// Response containing an error message, matching Hummingbird's error format
public struct ErrorResponse: Codable, Sendable {
    public let error: ErrorDetail
    
    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        
        public init(message: String) {
            self.message = message
        }
    }
    
    public init(message: String) {
        self.error = ErrorDetail(message: message)
    }
} 