import Foundation

extension Store {
    public enum Category: APIEndpoint {
        case getAll
        case get(id: String)
        case create(dto: CreateCategoryRequest)
        case update(id: String, dto: UpdateCategoryRequest)
        case delete(id: String)
        case getProducts(categoryId: String)
        
        public var path: String {
            switch self {
            case .getAll:
                return "/categories"
            case .get(let id), .update(let id, _), .delete(let id):
                return "/categories/\(id)"
            case .create:
                return "/categories"
            case .getProducts(let categoryId):
                return "/categories/\(categoryId)/products"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .create:
                return .post
            case .update:
                return .put
            case .delete:
                return .delete
            default:
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
