import SwiftUI
import Networking

struct FavoritesView: View {
    @Environment(FavoritesManager.self) private var favoritesManager
    @Namespace private var namespace
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    
    private let columns = [
        GridItem(.adaptive(minimum: 120), spacing: 10)
    ]
    
    var filteredProducts: [ProductResponse] {
        let favorites = favoritesManager.getFavoriteProducts()
        if searchText.isEmpty {
            return favorites
        }
        return favorites.filter { product in
            product.title.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(filteredProducts) { product in
                        NavigationLink(value: product) {
                            ProductCard(product: product, namespace: namespace)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Favorites")
            .withAccountButton()
            .searchable(text: $searchText, prompt: "Search favorites")
            .navigationDestination(for: ProductResponse.self) { product in
                ProductDetailView(product: product, namespace: namespace)
            }
            .navigationDestination(for: CategoryResponse.self) { category in
                ProductsListView(namespace: namespace)
            }
            .overlay {
                if filteredProducts.isEmpty {
                    ContentUnavailableView {
                        Label("No Favorites", systemImage: "heart.slash")
                    } description: {
                        Text(searchText.isEmpty ? 
                             "Add some products to your favorites" : 
                             "No favorites match your search"
                        )
                    }
                }
            }
        }
    }
} 
