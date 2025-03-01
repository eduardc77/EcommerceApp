public struct ProductResponse: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let description: String
    public let price: Double
    public let images: [String]
    public let category: CategoryResponse
    public let seller: UserResponse
    public let createdAt: String
    public let updatedAt: String
    
    public init(
        id: String,
        title: String,
        description: String,
        price: Double,
        images: [String],
        category: CategoryResponse,
        seller: UserResponse,
        createdAt: String,
        updatedAt: String
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.price = price
        self.images = images
        self.category = category
        self.seller = seller
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
} 
