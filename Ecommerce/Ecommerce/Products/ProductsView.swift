import SwiftUI
import Networking

struct ProductsView: View {
    @State private var navigationPath = NavigationPath()
    @Namespace private var namespace
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ProductsListView(namespace: namespace)
                .navigationTitle("Products")
                .withAccountButton()
                .navigationDestination(for: CategoryResponse.self) { category in
                    ProductsListView(category: category, namespace: namespace)
                        .navigationTitle(category.name)
                }
        }
    }
} 
