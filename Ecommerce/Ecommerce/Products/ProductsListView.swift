import SwiftUI
import Networking

struct ProductsListView: View {

    @Environment(ProductManager.self) private var productManager
    let namespace: Namespace.ID
    
    @State private var showFilters = false
    @State private var showAddProduct = false
    @State private var filterDTO = ProductFilterRequest()
    @State private var searchText = ""
    @State private var viewMode: ViewMode = .grid
    @State private var hasLoaded = false
    
    let category: CategoryResponse?
    
    init(category: CategoryResponse? = nil, namespace: Namespace.ID) {
        self.category = category
        self.namespace = namespace
    }
    
    var body: some View {
        ZStack {
            Group {
                switch viewMode {
                case .grid:
                    productsGrid
                case .list:
                    productsList
                }
            }
            .searchable(text: $searchText, prompt: "Search products")
            
            if productManager.isLoading {
                ProgressView()
            } else if productManager.products.isEmpty {
                emptyContentView
            }
        }
        .navigationDestination(for: ProductResponse.self) { product in
            ProductDetailView(product: product, namespace: namespace)
        }
        .onChange(of: searchText) { _, newValue in
            let dto = ProductFilterRequest(
                title: newValue.isEmpty ? nil : newValue
            )
            
            Task {
                await productManager.filterProducts(dto)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        withAnimation {
                            viewMode = viewMode == .grid ? .list : .grid
                        }
                    } label: {
                        Label(
                            viewMode == .grid ? "List View" : "Grid View",
                            systemImage: viewMode == .grid ? "list.bullet" : "square.grid.2x2"
                        )
                    }
                    
                    Button {
                        showFilters = true
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                    
                    Button {
                        showAddProduct = true
                    } label: {
                        Label("Add Product", systemImage: "plus.circle")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationStack {
                ProductFilterView(filterDTO: $filterDTO)
                    .onChange(of: filterDTO) { _, newValue in
                        Task {
                            await productManager.filterProducts(newValue)
                        }
                    }
            }
        }
        .sheet(isPresented: $showAddProduct) {
            NavigationStack {
                AddProductView()
            }
        }
        .refreshable {
            if let category = category {
                await productManager.loadProductsByCategory(category.id)
            } else {
                await productManager.loadProducts()
            }
        }
        .task {
            if !hasLoaded || productManager.currentCategoryId != category?.id {
                if let category = category {
                    await productManager.loadProductsByCategory(category.id)
                } else {
                    await productManager.loadProducts()
                }
                hasLoaded = true
            }
        }
    }
    
    private var productsGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                ForEach(productManager.products) { product in
                    NavigationLink(value: product) {
                        ProductCard(product: product, namespace: namespace)
                            .task {
                                if product == productManager.products.last {
                                    Task {
                                        await productManager.loadMoreProducts()
                                    }
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private var productsList: some View {
        List {
            ForEach(productManager.products) { product in
                NavigationLink(value: product) {
                    ProductRow(product: product, namespace: namespace)
                        .buttonStyle(.plain)
                        .task {
                            if product == productManager.products.last {
                                Task {
                                    await productManager.loadMoreProducts()
                                }
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private var emptyContentView: some View {
        ContentUnavailableView {
            Label("No Products", systemImage: "square.grid.2x2")
        } description: {
            if !searchText.isEmpty {
                Text("No products match your search")
            } else {
                Text(category == nil ? "No products available" : "No products in this category")
            }
        }
    }
} 

private extension ProductsListView {

    enum ViewMode {
        case grid
        case list
    }
}
