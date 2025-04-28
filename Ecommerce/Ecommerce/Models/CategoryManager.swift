import Observation
import Networking

@Observable
@MainActor
public final class CategoryManager {
    private let categoryService: CategoryService
    
    public var categories: [CategoryResponse] = []
    public var isLoading = false
    public var error: Error?
    
    public init(categoryService: CategoryService) {
        self.categoryService = categoryService
    }
    
    public func loadCategories() async {
        isLoading = true
        error = nil
        do {
            categories = try await categoryService.getAllCategories()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func getCategory(id: String) async -> CategoryResponse? {
        isLoading = true
        error = nil
        do {
            let category = try await categoryService.getCategory(id: id)
            isLoading = false
            return category
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    public func createCategory(_ dto: CreateCategoryRequest) async {
        isLoading = true
        error = nil
        do {
            let newCategory = try await categoryService.createCategory(dto)
            categories.append(newCategory)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func updateCategory(id: String, dto: UpdateCategoryRequest) async {
        isLoading = true
        error = nil
        do {
            let updatedCategory = try await categoryService.updateCategory(id: id, dto: dto)
            if let index = categories.firstIndex(where: { $0.id == id }) {
                categories[index] = updatedCategory
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func deleteCategory(id: String) async {
        isLoading = true
        error = nil
        do {
            try await categoryService.deleteCategory(id: id)
            categories.removeAll { $0.id == id }
        } catch {
            self.error = error
        }
        isLoading = false
    }
} 
