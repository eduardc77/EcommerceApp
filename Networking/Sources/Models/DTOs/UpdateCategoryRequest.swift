public struct UpdateCategoryRequest: Codable, Sendable {
    public let name: String?
    public let description: String?
    public let image: String?
    
    public init(
        name: String? = nil,
        description: String? = nil,
        image: String? = nil
    ) {
        self.name = name
        self.description = description
        self.image = image
    }
} 