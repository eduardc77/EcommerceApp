import Foundation

extension Store {
    public enum OIDC: APIEndpoint {
        case discovery
        case jwks
        
        public var path: String {
            switch self {
            case .discovery:
                return "/.well-known/openid-configuration"
            case .jwks:
                return "/.well-known/jwks.json"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .discovery, .jwks:
                return .get
            }
        }
        
        public var requestBody: Any? { nil }
        
        public var headers: [String: String]? { nil }
        
        public var formParams: [String: String]? { nil }
    }
} 