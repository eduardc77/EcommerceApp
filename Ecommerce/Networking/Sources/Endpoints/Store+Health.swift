import Foundation

public extension Store {
    enum Health: APIEndpoint {
        case check
        
        public var path: String {
            switch self {
            case .check:
                return "/health"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .check:
                return .get
            }
        }
        
        public var requestBody: Any? { nil }
        public var formParams: [String: String]? { nil }
    }
}

public struct HealthCheckResponse: Codable, Sendable {
    public let status: String
    public let version: String
    public let timestamp: Date
    
    public init(status: String, version: String, timestamp: Date) {
        self.status = status
        self.version = version
        self.timestamp = timestamp
    }
} 