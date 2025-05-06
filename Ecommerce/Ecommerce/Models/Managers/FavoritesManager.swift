import SwiftUI
import Networking

@Observable
final class FavoritesManager {
    private let defaults = UserDefaults.standard
    private let favoritesKey = "favoriteProducts"
    private let productsKey = "favoriteProductsData"
    
    // Store both IDs and products
    private var _favoriteIds: Set<String> = []
    private var _favoriteProducts: [ProductResponse] = [] {
        didSet {
            _favoriteIds = Set(_favoriteProducts.map { $0.id })
            // Save both IDs and products to UserDefaults
            if let idData = try? JSONEncoder().encode(Array(_favoriteIds)) {
                defaults.set(idData, forKey: favoritesKey)
            }
            if let productData = try? JSONEncoder().encode(_favoriteProducts) {
                defaults.set(productData, forKey: productsKey)
            }
        }
    }
    
    init() {
        // Load from UserDefaults on initialization
        if let productData = defaults.data(forKey: productsKey),
           let products = try? JSONDecoder().decode([ProductResponse].self, from: productData) {
            _favoriteProducts = products
            _favoriteIds = Set(products.map { $0.id })
        } else if let idData = defaults.data(forKey: favoritesKey),
                  let ids = try? JSONDecoder().decode([String].self, from: idData) {
            _favoriteIds = Set(ids)
        }
    }
    
    func toggleFavorite(_ product: ProductResponse) {
        if _favoriteIds.contains(product.id) {
            _favoriteProducts.removeAll { $0.id == product.id }
        } else {
            // If we have existing products, maintain their order
            if !_favoriteProducts.isEmpty {
                _favoriteProducts.append(product)
            } else {
                // If this is the first product, initialize the array
                _favoriteProducts = [product]
            }
        }
    }
    
    func isFavorite(_ productId: String) -> Bool {
        _favoriteIds.contains(productId)
    }
    
    func getFavoriteProducts() -> [ProductResponse] {
        _favoriteProducts
    }
    
    func getFavoriteIds() -> Set<String> {
        _favoriteIds
    }
} 
