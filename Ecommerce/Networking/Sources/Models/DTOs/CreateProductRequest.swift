public struct CreateProductRequest: Codable, Sendable {
    public let title: String
    public let description: String
    public let price: Double
    public let images: [String]
    public let categoryId: String
    
    public init(
        title: String,
        description: String,
        price: Double,
        images: [String],
        categoryId: String
    ) {
        self.title = title
        self.description = description
        self.price = price
        self.images = images
        self.categoryId = categoryId
    }
} 