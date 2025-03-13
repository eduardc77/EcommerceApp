import Foundation

extension Store {
    public enum User: APIEndpoint {
        case getAll
        case get(id: String)
        case getPublic(id: String)
        case create(dto: CreateUserRequest)
        case update(id: String, dto: UpdateUserRequest)
        case checkAvailability(type: AvailabilityType)
        
        public var path: String {
            switch self {
            case .getAll:
                return "/users"
            case .get(let id):
                return "/users/\(id)"
            case .getPublic(let id):
                return "/users/\(id)/public"
            case .create:
                return "/users"
            case .update(let id, _):
                return "/users/\(id)"
            case .checkAvailability(type):
                let query = type.queryItem
                return "/users/availability?\(query.key)=\(query.value)"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .create:
                return .post
            case .update:
                return .put
            case .getAll, .get, .getPublic, .checkAvailability:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .create(let dto):
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
