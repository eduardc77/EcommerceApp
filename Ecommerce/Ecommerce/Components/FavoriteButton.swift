import SwiftUI
import Networking

struct FavoriteButton: View {
    let product: ProductResponse
    @Environment(FavoritesManager.self) private var favoritesManager
    @Environment(ToastManager.self) private var toastManager
    
    var body: some View {
        Button {
            withAnimation {
                favoritesManager.toggleFavorite(product)
                toastManager.show(
                    favoritesManager.isFavorite(product.id) ? .addedToFavorites : .removedFromFavorites
                )
            }
        } label: {
            Label("Favorite", systemImage: favoritesManager.isFavorite(product.id) ? "heart.fill" : "heart")
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(favoritesManager.isFavorite(product.id) ? .red : .gray)
    }
}

struct AddToCartButton: View {
    let product: ProductResponse
    @Environment(CartManager.self) private var cartManager
    @Environment(ToastManager.self) private var toastManager
    
    var body: some View {
        Button {
            withAnimation {
                cartManager.addToCart(1, product: product)
                toastManager.show(.addedToCart)
            }
        } label: {
            Label("Add to Cart", systemImage: "cart.badge.plus")
                .labelStyle(.iconOnly)
                .contentTransition(.symbolEffect(.replace))
        }
        .foregroundStyle(.blue)
    }
} 
