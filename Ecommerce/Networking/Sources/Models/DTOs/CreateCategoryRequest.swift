public struct CreateCategoryRequest: Codable, Sendable {
    public let name: String
    public let description: String
    public let image: String
    
    public init(
        name: String,
        description: String,
        image: String
    ) {
        self.name = name
        self.description = description
        self.image = image
    }
} 