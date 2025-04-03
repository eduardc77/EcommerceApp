import SwiftUI
import Networking

struct ProductCard: View {
    let product: ProductResponse
    let namespace: Namespace.ID

    @Environment(ProductManager.self) private var productManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(CartManager.self) private var cartManager
    @Environment(ToastManager.self) private var toastManager
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationLink(value: product) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    AsyncImage(url: URL(string: product.images.first ?? "")) { image in
                        image
                            .resizable()
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .scaledToFit()
                    } placeholder: {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "bag.circle")
                                    .resizable()
                                    .frame(width: 100, height: 100)
                                    .foregroundStyle(.white)
                            }
                            .frame(height: 150)
                            .frame(maxWidth: .infinity)
                    }

                    FavoriteButton(product: product)
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(.circle)
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(product.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(product.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.bottom, 4)

                    HStack {
                        Text(product.price.formatted(.currency(code: "USD")))
                            .foregroundStyle(.secondary)

                        Spacer()

                        AddToCartButton(product: product)
                            .padding(4)
                            .background(.ultraThinMaterial)
                            .clipShape(.circle)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
        }
        .buttonStyle(.plain)
        .padding(10)
        .frame(height: 280)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.1))
        }
        .transitionSource(id: product.id, namespace: namespace)
        .contextMenu {
            if authManager.currentUser?.role == .admin {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .alert("Delete Product", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await productManager.deleteProduct(id: product.id)
                }
            }
        } message: {
            Text("Are you sure you want to delete this product? This action cannot be undone.")
        }
    }
}

#Preview {
    ProductCard(
        product: ProductResponse(
            id: "1",
            title: "Test Product",
            description: "This is a test product description that might be long",
            price: 99.99,
            images: ["https://picsum.photos/200", "https://picsum.photos/201"],
            category: CategoryResponse(
                id: "1",
                name: "Test",
                description: "Test category",
                image: "",
                createdAt: "2025-02-23T21:51:49.000Z",
                updatedAt: "2025-02-23T21:51:49.000Z",
                productCount: 2
            ),
            seller: .previewUser,
            createdAt: "2025-02-23T21:51:49.000Z",
            updatedAt: "2025-02-23T21:51:49.000Z"
        ),
        namespace: Namespace().wrappedValue
    )
    .padding()
}
