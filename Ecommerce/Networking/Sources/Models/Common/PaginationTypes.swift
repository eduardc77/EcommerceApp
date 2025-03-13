import Foundation

public struct PaginationRequest: Codable, Sendable {
    public let page: Int
    public let limit: Int
    public let sortBy: String?
    public let sortOrder: SortOrder?
    
    public init(page: Int = 1, limit: Int = 20, sortBy: String? = nil, sortOrder: SortOrder? = nil) {
        self.page = page
        self.limit = limit
        self.sortBy = sortBy
        self.sortOrder = sortOrder
    }
}

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let total: Int
    public let page: Int
    public let limit: Int
    public let hasMore: Bool
    
    public init(items: [T], total: Int, page: Int, limit: Int) {
        self.items = items
        self.total = total
        self.page = page
        self.limit = limit
        self.hasMore = (page * limit) < total
    }
}

public enum SortOrder: String, Codable, Sendable {
    case ascending = "asc"
    case descending = "desc"
}

public struct SearchRequest: Codable, Sendable {
    public let query: String
    public let filters: [String: String]?
    public let pagination: PaginationRequest?
    
    public init(query: String, filters: [String: String]? = nil, pagination: PaginationRequest? = nil) {
        self.query = query
        self.filters = filters
        self.pagination = pagination
    }
} 