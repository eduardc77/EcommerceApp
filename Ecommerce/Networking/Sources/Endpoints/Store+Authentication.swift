import Foundation

extension Store {
    
    public enum Authentication: APIEndpoint {
        case login(dto: LoginRequest)
        case register(dto: CreateUserRequest)
        case refreshToken(_ token: String)
        case logout
        case me
        
        public var path: String {
            switch self {
                case .login:
                    return "/auth/login"
                case .register:
                    return "/auth/register"
                case .refreshToken:
                    return "/auth/refresh"
                case .logout:
                    return "/auth/logout"
                case .me:
                    return "/auth/me"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
                case .login, .register, .refreshToken, .logout:
                    return .post
                case .me:
                    return .get
            }
        }
        
        public var headers: [String: String]? {
            switch self {
                case .login(let dto):
                    let credentials = "\(dto.identifier):\(dto.password)".data(using: .utf8)?.base64EncodedString() ?? ""
                    return ["Authorization": "Basic \(credentials)"]
                case .refreshToken(let token):
                    return ["Authorization": "Bearer \(token)"]
                default:
                    return nil
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .login(let dto):
                return nil  // Credentials are in Authorization header
            case .register(let dto):
                return dto
            case .refreshToken(let token):
                return ["refreshToken": token]
            case .logout, .me:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
}
