public actor CategoryService {
    private let apiClient: APIClient
    private let environment: Store.Environment
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    public func getAllCategories() async throws -> [CategoryResponse] {
        try await apiClient.performRequest(
            from: Store.Category.getAll,
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func getCategory(id: String) async throws -> CategoryResponse {
        try await apiClient.performRequest(
            from: Store.Category.get(id: id),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func createCategory(_ dto: CreateCategoryRequest) async throws -> CategoryResponse {
        try await apiClient.performRequest(
            from: Store.Category.create(dto: dto),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func updateCategory(id: String, dto: UpdateCategoryRequest) async throws -> CategoryResponse {
        try await apiClient.performRequest(
            from: Store.Category.update(id: id, dto: dto),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
    
    public func deleteCategory(id: String) async throws {
        let _: EmptyResponse = try await apiClient.performRequest(
            from: Store.Category.delete(id: id),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
    }
    
    public func getProductsByCategory(categoryId: String) async throws -> [ProductResponse] {
        try await apiClient.performRequest(
            from: Store.Category.getProducts(categoryId: categoryId),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
    }
} 
