public struct CategoryResponse: Codable, Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let image: String
    public let createdAt: String
    public let updatedAt: String
    public let productCount: Int
    
    public init(
        id: String,
        name: String,
        description: String,
        image: String,
        createdAt: String,
        updatedAt: String,
        productCount: Int
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.image = image
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.productCount = productCount
    }
} 
