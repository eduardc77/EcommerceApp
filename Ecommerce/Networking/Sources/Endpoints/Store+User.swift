import Foundation

extension Store {
    public enum AvailabilityType: Sendable {
        case username(String)
        case email(String)
        
        var queryItem: (key: String, value: String) {
            switch self {
            case .username(let value): return ("username", value)
            case .email(let value): return ("email", value)
            }
        }
    }
    
    public enum User: APIEndpoint {
        case getAll
        case get(id: String)
        case register(dto: CreateUserRequest)
        case update(id: String, dto: UpdateUserRequest)
        case checkAvailability(type: AvailabilityType)
        
        public var path: String {
            switch self {
            case .getAll:
                return "/users"
            case .get(let id), .update(let id, _):
                return "/users/\(id)"
            case .register:
                return "/users/register"
            case .checkAvailability(type):
                let query = type.queryItem
                return "/users/availability?\(query.key)=\(query.value)"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .register:
                return .post
            case .update:
                return .put
            case .getAll, .get, .checkAvailability:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .register(let dto):
                return dto
            case .update(_, let dto):
                return dto
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
} 
