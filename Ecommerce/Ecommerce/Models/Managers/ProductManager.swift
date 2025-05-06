import Observation
import Networking
import SwiftUI

@Observable
@MainActor
public final class ProductManager {
    private enum FilterKey {
        static let title = "title"
        static let minPrice = "min_price"
        static let maxPrice = "max_price"
        static let categoryId = "categoryId"
        static let sellerId = "sellerId"
        static let sortBy = "sortBy"
        static let order = "order"
        static let page = "page"
        static let limit = "limit"
    }

    // Constants
    public let pageSize = 10
    public var currentCategoryId: String?

    private let productService: ProductService
    private let categoryService: CategoryService

    public var products: [ProductResponse] = []
    public var isLoading = false
    public var error: Error?
    public var hasMoreProducts = true

    private var currentPage = 0
    private var isFetching = false
    private var canLoadMore = true
    private var isFiltered = false
    private var currentFilters: [String: String] = [:]

    public init(
        productService: ProductService,
        categoryService: CategoryService
    ) {
        self.productService = productService
        self.categoryService = categoryService
    }

    @MainActor
    public func loadProducts() async {
        isFiltered = false
        isLoading = true
        error = nil
        do {
            currentPage = 0
            canLoadMore = true
            products = try await productService.getAllProducts(
                offset: 0,
                limit: pageSize
            )
        } catch {
            self.error = error
        }
        isLoading = false
    }

    public func loadProductsByCategory(_ categoryId: String) async {
        guard !isFetching else { return }
        currentCategoryId = categoryId
        currentPage = 0
        isLoading = true
        isFetching = true
        error = nil
        
        do {
            let response = try await productService.getAllProducts(
                offset: 0,
                limit: pageSize,
                categoryId: categoryId
            )
            products = response
            hasMoreProducts = response.count >= pageSize
        } catch {
            self.error = error
            products = []
            hasMoreProducts = false
        }
        isLoading = false
        isFetching = false
    }

    @MainActor
    public func loadMoreProducts() async {
        guard !isLoading && canLoadMore else { return }
        
        isLoading = true
        do {
            let nextPage: [ProductResponse]
            if isFiltered {
                // Apply filters with next page
                var paginatedFilters = currentFilters
                paginatedFilters[FilterKey.page] = "\(currentPage + 1)"
                paginatedFilters[FilterKey.limit] = "\(pageSize)"
                
                let dto = ProductFilterRequest(
                    title: paginatedFilters[FilterKey.title],
                    minPrice: paginatedFilters[FilterKey.minPrice].flatMap(Double.init),
                    maxPrice: paginatedFilters[FilterKey.maxPrice].flatMap(Double.init),
                    categoryId: paginatedFilters[FilterKey.categoryId],
                    sellerId: paginatedFilters[FilterKey.sellerId],
                    sortBy: paginatedFilters[FilterKey.sortBy],
                    order: paginatedFilters[FilterKey.order],
                    page: paginatedFilters[FilterKey.page].flatMap(Int.init),
                    limit: paginatedFilters[FilterKey.limit].flatMap(Int.init)
                )
                nextPage = try await productService.filterProducts(dto)
                
                // Stop if we got fewer items than requested
                if nextPage.count < pageSize {
                    canLoadMore = false
                }
            } else {
                nextPage = try await productService.getAllProducts(
                    offset: (currentPage + 1) * pageSize,
                    limit: pageSize
                )
                
                if nextPage.isEmpty {
                    canLoadMore = false
                }
            }
            
            if !nextPage.isEmpty {
                currentPage += 1
                // Filter out duplicates before appending
                let newProducts = nextPage.filter { newProduct in
                    !products.contains { $0.id == newProduct.id }
                }
                products.append(contentsOf: newProducts)
            } else {
                canLoadMore = false
            }
        } catch {
            self.error = error
            canLoadMore = false
        }
        isLoading = false
    }

    public func createProduct(_ dto: CreateProductRequest) async {
        isLoading = true
        error = nil
        do {
            let _ = try await productService.createProduct(dto)
            // Reload the current category/filter to maintain consistency
            if isFiltered {
                // If we're in filtered view, apply current filters
                await filterProducts(ProductFilterRequest(
                    title: currentFilters[FilterKey.title],
                    minPrice: currentFilters[FilterKey.minPrice].flatMap(Double.init),
                    maxPrice: currentFilters[FilterKey.maxPrice].flatMap(Double.init),
                    categoryId: currentFilters[FilterKey.categoryId],
                    sellerId: currentFilters[FilterKey.sellerId],
                    sortBy: currentFilters[FilterKey.sortBy],
                    order: currentFilters[FilterKey.order],
                    page: 0,
                    limit: (currentPage + 1) * pageSize  // Load all current pages
                ))
            } else if let categoryId = currentCategoryId {
                // If we're in a category, reload it
                await loadProductsByCategory(categoryId)
            } else {
                // If we're in all products view, reload all
                await loadProducts()
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    public func updateProduct(id: String, dto: UpdateProductRequest) async {
        isLoading = true
        error = nil
        do {
            let updatedProduct = try await productService.updateProduct(id: id, dto: dto)
            if let index = products.firstIndex(where: { $0.id == id }) {
                products[index] = updatedProduct
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    public func deleteProduct(id: String) async {
        isLoading = true
        error = nil
        do {
            try await productService.deleteProduct(id: id)
            products.removeAll { $0.id == id }
        } catch {
            self.error = error
        }
        isLoading = false
    }

    @MainActor
    public func filterProducts(_ dto: ProductFilterRequest) async {
        isFiltered = true
        isLoading = true
        currentPage = 0  // Reset page when applying new filters
        
        // Store filters for pagination
        let filters: [String: String?] = [
            FilterKey.title: dto.title,
            FilterKey.minPrice: dto.minPrice.map { String($0) },
            FilterKey.maxPrice: dto.maxPrice.map { String($0) },
            FilterKey.categoryId: dto.categoryId,
            FilterKey.sellerId: dto.sellerId,
            FilterKey.sortBy: dto.sortBy,
            FilterKey.order: dto.order
        ]
        currentFilters = filters.compactMapValues { $0 }
        
        do {
            products = try await productService.filterProducts(dto)
            error = nil
            canLoadMore = products.count >= pageSize
        } catch {
            self.error = error
            canLoadMore = false
        }
        isLoading = false
    }
}
