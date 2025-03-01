public struct ProductFilterRequest: Codable, Sendable, Equatable {
    public let title: String?
    public let minPrice: Double?
    public let maxPrice: Double?
    public let categoryId: String?
    public let sellerId: String?
    public let sortBy: String?
    public let order: String?
    public let page: Int?
    public let limit: Int?

    public init(
        title: String? = nil,
        minPrice: Double? = nil,
        maxPrice: Double? = nil,
        categoryId: String? = nil,
        sellerId: String? = nil,
        sortBy: String? = nil,
        order: String? = nil,
        page: Int? = nil,
        limit: Int? = nil
    ) {
        self.title = title
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.categoryId = categoryId
        self.sellerId = sellerId
        self.sortBy = sortBy
        self.order = order
        self.page = page
        self.limit = limit
    }
} 
