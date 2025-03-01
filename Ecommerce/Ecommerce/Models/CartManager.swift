import Foundation
import Networking

struct CartItem: Identifiable {
    let id: Int
    let product: ProductResponse
    var quantity: Int
}

@Observable
public final class CartManager {
    private(set) var items: [CartItem] = []
    
    var subtotal: Double {
        items.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    
    var tax: Double {
        subtotal * 0.08 // 8% tax
    }
    
    var total: Double {
        subtotal + tax
    }
    
    public init() {}
    
    func updateQuantity(_ quantity: Int, for product: ProductResponse) {
        if quantity <= 0 {
            items.removeAll { $0.product.id == product.id }
        } else if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity = quantity // Set directly for cart stepper
        } else {
            items.append(CartItem(id: items.count + 1, product: product, quantity: quantity))
        }
    }
    
    func addToCart(_ quantity: Int, product: ProductResponse) {
        if let index = items.firstIndex(where: { $0.product.id == product.id }) {
            items[index].quantity += quantity // Add for "Add to Cart" button
        } else {
            items.append(CartItem(id: items.count + 1, product: product, quantity: quantity))
        }
    }
    
    func removeItems(at indexSet: IndexSet) {
        items.remove(atOffsets: indexSet)
    }
    
    func clearCart() {
        items.removeAll()
    }
} 
