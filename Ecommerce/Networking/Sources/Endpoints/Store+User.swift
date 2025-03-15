import Foundation

public extension Store {
    enum User: APIEndpoint {
        case getAll
        case get(id: String)
        case getPublic(id: String)
        case register(dto: CreateUserRequest)
        case create(dto: CreateUserRequest)
        case updateProfile(dto: UpdateUserRequest)
        case adminUpdate(id: String, dto: UpdateUserRequest)
        case delete(id: String)
        case checkAvailability(type: AvailabilityType)
        case updateRole(String)
        
        public var path: String {
            switch self {
            case .getAll:
                return "/users"
            case .get(let id):
                return "/users/\(id)"
            case .getPublic(let id):
                return "/users/\(id)/public"
            case .register:
                return "/users/register"
            case .create:
                return "/users"
            case .updateProfile:
                return "/users/update-profile"
            case .adminUpdate(let id, _):
                return "/users/\(id)"
            case .delete(let id):
                return "/users/\(id)"
            case .checkAvailability(let type):
                let query = type.queryItem
                return "/users/availability?\(query.key)=\(query.value)"
            case .updateRole(let userId):
                return "/users/\(userId)/role"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .register, .create:
                return .post
            case .updateProfile, .adminUpdate, .updateRole:
                return .put
            case .delete:
                return .delete
            case .getAll, .get, .getPublic, .checkAvailability:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .register(let dto), .create(let dto):
                return dto
            case .updateProfile(let dto), .adminUpdate(_, let dto):
                return dto
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
} 
