import Foundation

extension Store {
    /// This enum defines all product-related endpoints including categories
    public enum Product: APIEndpoint {
        // Products
        case getAll(categoryId: String? = nil, offset: Int = 0, limit: Int = 10)
        case get(id: String)
        case create(dto: CreateProductRequest)
        case update(id: String, dto: UpdateProductRequest)
        case delete(id: String)
        case filter(dto: ProductFilterRequest)

        public var path: String {
            switch self {
                // Product paths
            case .getAll, .create, .filter:
                return "/products"
            case .get(let id), .update(let id, _), .delete(let id):
                return "/products/\(id)"
            }
        }

        public var queryParams: [String: String]? {
            switch self {
            case .getAll(let categoryId, let offset, let limit):
                var params = [
                    "page": "\(offset / limit + 1)",
                    "limit": "\(limit)"
                ]
                if let categoryId {
                    params["categoryId"] = categoryId
                }
                return params

            case .filter(let dto):
                var params: [String: String] = [:]
                if let name = dto.title {
                    params["name"] = name
                }
                if let minPrice = dto.minPrice {
                    params["min_price"] = "\(minPrice)"
                }
                if let maxPrice = dto.maxPrice {
                    params["max_price"] = "\(maxPrice)"
                }
                if let categoryId = dto.categoryId {
                    params["categoryId"] = categoryId
                }
                if let sellerId = dto.sellerId {
                    params["sellerId"] = sellerId
                }
                if let sortBy = dto.sortBy {
                    params["sortBy"] = sortBy
                }
                if let order = dto.order {
                    params["order"] = order
                }
                if let page = dto.page {
                    params["page"] = "\(page)"
                }
                if let limit = dto.limit {
                    params["limit"] = "\(limit)"
                }
                return params

            default:
                return nil
            }
        }

        public var httpMethod: HTTPMethod {
            switch self {
            case .getAll, .get, .filter:
                return .get
            case .create:
                return .post
            case .update:
                return .put
            case .delete:
                return .delete
            }
        }

        public var mockFile: String? {
            switch self {
            case .getAll:
                return "_mockProductsResponse"
            case .get:
                return "_mockProductResponse"
            default:
                return nil
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
