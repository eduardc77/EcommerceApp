import Foundation

extension Store {

    public enum Environment: APIEnvironment {
        case production
        case staging
        case develop
        
        public var scheme: String { "http" }
        
        public var host: String {
            switch self {
            case .production:
                return "api.ecommerce.com"
            case .staging:
                return "staging.ecommerce.com"
            case .develop:
                return "localhost"
            }
        }
        
        public var port: Int? {
            switch self {
            case .production, .staging:
                return nil
            case .develop:
                return 8080
            }
        }
        
        public var headers: [String: String]? {
            [
                "Accept": "application/json",
                "Content-Type": "application/json"
            ]
        }
        
        public var queryParams: [String: String]? {
            nil
        }
        
        public var apiVersion: String? {
            "/v1"
        }
        
        public var domain: String {
            "/api"
        }
    }
}
