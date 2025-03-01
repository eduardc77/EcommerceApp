public struct UpdateProductRequest: Codable, Sendable {
    public let title: String?
    public let description: String?
    public let price: Double?
    public let images: [String]?
    public let categoryId: String?

    public init(
        title: String? = nil,
        description: String? = nil,
        price: Double? = nil,
        images: [String]? = nil,
        categoryId: String? = nil
    ) {
        self.title = title
        self.description = description
        self.price = price
        self.images = images
        self.categoryId = categoryId
    }
}
