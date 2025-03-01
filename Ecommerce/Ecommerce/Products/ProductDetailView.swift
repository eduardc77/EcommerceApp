import SwiftUI
import Networking

struct ProductDetailView: View {
    let product: ProductResponse
    let namespace: Namespace.ID
    
    @Environment(ProductManager.self) private var productManager
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(CartManager.self) private var cartManager
    @Environment(ToastManager.self) private var toastManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showDeleteConfirmation = false
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var editedPrice = 0.0
    @State private var editedDescription = ""
    @State private var quantity = 1
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Image Gallery
                ImageGalleryView(images: product.images)
                
                // Product Info
                VStack(alignment: .leading, spacing: 12) {
                    if isEditing {
                        TextField("Name", text: $editedName)
                            .font(.title2.weight(.bold))
                        
                        TextField("Price", value: $editedPrice, format: .currency(code: "USD"))
                            .keyboardType(.decimalPad)
                        
                        TextField("Description", text: $editedDescription, axis: .vertical)
                            .lineLimit(3...6)
                    } else {
                        Text(product.title)
                            .font(.title2.weight(.bold))
                        
                        Text(product.price.formatted(.currency(code: "USD")))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        Text(product.description)
                            .foregroundStyle(.secondary)
                    }
                    
                    if permissionManager.canManageProduct(product) {
                        HStack {
                            if isEditing {
                                Button("Cancel") {
                                    isEditing = false
                                }
                                .buttonStyle(.bordered)
                                
                                Button("Save") {
                                    Task {
                                        await updateProduct()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Edit") {
                                    editedName = product.title
                                    editedPrice = product.price
                                    editedDescription = product.description
                                    isEditing = true
                                }
                                .buttonStyle(.bordered)
                                
                                Button(role: .destructive) {
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.top)
                    } else {
                        Stepper(value: $quantity, in: 1...99) {
                            HStack {
                                Text("Quantity")
                                Spacer()
                                Text("\(quantity)")
                                    .monospacedDigit()
                                    .contentTransition(.numericText(value: Double(quantity)))
                            }
                        }
                        .padding(.top)
                        
                        Button {
                            cartManager.addToCart(quantity, product: product)
                            toastManager.show(.addedToCart)
                        } label: {
                            Text("Add to Cart")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                }
                .padding(.horizontal)
                
                // Category Info
                if !isEditing {
                    CategoryInfoView(category: product.category)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTransition(.zoom(sourceID: product.id, in: namespace))
        .alert("Delete Product", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteProduct()
                }
            }
        } message: {
            Text("Are you sure you want to delete this product? This action cannot be undone.")
        }
    }
    
    private func updateProduct() async {
        let dto = UpdateProductRequest(
            title: editedName,
            description: editedDescription,
            price: editedPrice
        )
        await productManager.updateProduct(id: product.id, dto: dto)
        isEditing = false
    }
    
    private func deleteProduct() async {
        await productManager.deleteProduct(id: product.id)
        dismiss()
    }
}

// MARK: - Subviews
private struct ImageGalleryView: View {
    let images: [String]
    
    var body: some View {
        TabView {
            ForEach(images, id: \.self) { imageURL in
                AsyncImage(url: URL(string: imageURL)) { image in
                    image
                        .resizable()
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .scaledToFit()
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "bag.circle")
                                .resizable()
                                .frame(height: 300)
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(.white)
                        }
                }
            }
        }
        .tabViewStyle(.page)
        .frame(height: 300)
    }
}

private struct CategoryInfoView: View {
    let category: CategoryResponse
    
    var body: some View {
        NavigationLink(value: category) {
            HStack {
                AsyncImage(url: URL(string: category.image)) { image in
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } placeholder: {
                    Color.gray.opacity(0.2)
                        .frame(width: 50, height: 50)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading) {
                    Text(category.name)
                        .font(.headline)
                    Text(category.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.quaternary)
            }
        }
    }
} 
