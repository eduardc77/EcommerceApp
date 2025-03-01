import Foundation

extension Store {

    public enum Environment: APIEnvironment {
        case production
        case staging
        case develop
        
        public var scheme: String { "http" }
        
        public var host: String {
            switch self {
            case .production, .staging, .develop:
                return "localhost"
            }
        }
        
        public var port: Int? {
            switch self {
            case .production, .staging, .develop:
                return 8080
            }
        }
        
        public var headers: [String: String]? {
            nil
        }
        
        public var queryParams: [String: String]? {
            nil
        }
        
        public var apiVersion: String? {
            nil
        }
        
        public var domain: String {
            ""
        }
    }
}
