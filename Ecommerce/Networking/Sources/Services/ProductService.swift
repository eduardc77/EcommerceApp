import OSLog
import Foundation

public protocol ProductServiceProtocol {
    func filterProducts(_ dto: ProductFilterRequest) async throws -> [ProductResponse]
    func getAllProducts(offset: Int?, limit: Int?, categoryId: String?) async throws -> [ProductResponse]
    func getProduct(id: String) async throws -> ProductResponse
    func createProduct(_ dto: CreateProductRequest) async throws -> ProductResponse
    func updateProduct(id: String, dto: UpdateProductRequest) async throws -> ProductResponse
    func deleteProduct(id: String) async throws
}

public actor ProductService: ProductServiceProtocol {
    private let apiClient: APIClient
    private let environment: Store.Environment
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Networking", category: "ProductService")
    
    public init(apiClient: APIClient) {
        self.apiClient = apiClient
        self.environment = .develop
    }
    
    // MARK: - Products
    
    public func getAllProducts(
        offset: Int? = nil,
        limit: Int? = nil,
        categoryId: String? = nil
    ) async throws -> [ProductResponse] {
        let products: [ProductResponse] = try await apiClient.performRequest(
            from: Store.Product.getAll(
                categoryId: categoryId,
                offset: offset ?? 0,
                limit: limit ?? 10
            ),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
        logger.debug("Fetched \(products.count, privacy: .public) products")
        return products
    }
    
    public func getProduct(id: String) async throws -> ProductResponse {
        let product: ProductResponse = try await apiClient.performRequest(
            from: Store.Product.get(id: id),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
        logger.debug("Fetched product with ID: \(id, privacy: .public)")
        return product
    }
    
    public func createProduct(_ dto: CreateProductRequest) async throws -> ProductResponse {
        do {
            let product: ProductResponse = try await apiClient.performRequest(
                from: Store.Product.create(dto: dto),
                in: environment,
                allowRetry: false,
                requiresAuthorization: false
            )
            logger.debug("Created product with ID: \(product.id, privacy: .public)")
            return product
        } catch {
            logger.error("Create product error: \(error, privacy: .public)")
            throw error
        }
    }
    
    public func updateProduct(id: String, dto: UpdateProductRequest) async throws -> ProductResponse {
        do {
            let product: ProductResponse = try await apiClient.performRequest(
                from: Store.Product.update(id: id, dto: dto),
                in: environment,
                allowRetry: true,
                requiresAuthorization: false
            )
            logger.debug("Updated product with ID: \(id, privacy: .public)")
            return product
        } catch {
            logger.error("Update product error: \(error, privacy: .public)")
            throw error
        }
    }
    
    public func deleteProduct(id: String) async throws {
        let _: EmptyResponse = try await apiClient.performRequest(
            from: Store.Product.delete(id: id),
            in: environment,
            allowRetry: false,
            requiresAuthorization: false
        )
        logger.debug("Deleted product with ID: \(id, privacy: .public)")
    }
    
    // MARK: - Filtering

    public func filterProducts(_ dto: ProductFilterRequest) async throws -> [ProductResponse] {
        let products: [ProductResponse] = try await apiClient.performRequest(
            from: Store.Product.filter(dto: dto),
            in: environment,
            allowRetry: true,
            requiresAuthorization: false
        )
        logger.debug("Filtered products, found \(products.count, privacy: .public) results")
        return products
    }
} 
