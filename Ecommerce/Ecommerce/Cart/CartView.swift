import SwiftUI
import Networking

struct CartView: View {
    @Environment(CartManager.self) private var cartManager
    @State private var showCheckout = false
    @Namespace private var namespace
    
    var body: some View {
        NavigationStack {
            ZStack {
                if cartManager.items.isEmpty {
                    ContentUnavailableView {
                        Label("Your Cart is Empty", systemImage: "cart")
                    } description: {
                        Text("Items you add to your cart will appear here")
                    } actions: {
                        Button("Browse Products") {
                            // TODO: Navigate to products
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        List {
                            ForEach(cartManager.items) { item in
                                CartItemRow(item: item, namespace: namespace)
                            }
                            .onDelete { indexSet in
                                withAnimation {
                                    cartManager.removeItems(at: indexSet)
                                }
                            }
                        }
                        .listStyle(.plain)
                        
                        VStack(spacing: 0) {
                            Divider()
                            VStack {
                                HStack {
                                    Text("Subtotal")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(cartManager.subtotal.formatted(.currency(code: "USD")))
                                        .fontWeight(.semibold)
                                        .contentTransition(.numericText(value: Double(cartManager.subtotal)))
                                }
                                
                                HStack {
                                    Text("Tax")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text(cartManager.tax.formatted(.currency(code: "USD")))
                                        .fontWeight(.semibold)
                                        .contentTransition(.numericText(value: Double(cartManager.tax)))
                                }
                                
                                Divider()
                                
                                HStack {
                                    Text("Total")
                                        .font(.headline)
                                    Spacer()
                                    Text(cartManager.total.formatted(.currency(code: "USD")))
                                        .font(.headline)
                                        .contentTransition(.numericText(value: Double(cartManager.total)))
                                }
                                
                                Button {
                                    showCheckout = true
                                } label: {
                                    Text("Checkout")
                                        .fontWeight(.semibold)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(.top)
                            }
                            .padding()
                            .background(.background)
                        }
                    }
                }
            }
            .navigationTitle("Cart")
            .navigationDestination(for: ProductResponse.self) { product in
                ProductDetailView(product: product, namespace: namespace)
            }
            .sheet(isPresented: $showCheckout) {
                NavigationStack {
                    CheckoutView()
                }
            }
        }
    }
}

struct CartItemRow: View {
    let item: CartItem
    let namespace: Namespace.ID
    @Environment(CartManager.self) private var cartManager
    
    var body: some View {
        NavigationLink(value: item.product) {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: item.product.images.first ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Rectangle()
                        .fill(.quaternary)
                }
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Text(item.product.price, format: .currency(code: "USD"))
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: item.product.price))
                        
                        if item.quantity > 1 {
                            Text("× \(item.quantity)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(item.quantity)))
                        }
                    }
                }
                
                Spacer()
                
                Stepper(
                    value: Binding(
                        get: { item.quantity },
                        set: { newValue in
                            withAnimation {
                                cartManager.updateQuantity(newValue, for: item.product)
                            }
                        }
                    ),
                    in: 1...99
                ) {
                    Text("\(item.quantity)")
                        .monospacedDigit()
                        .frame(minWidth: 24)
                        .contentTransition(.numericText(value: Double(item.quantity)))
                }
                .labelsHidden()
            }
            .padding(.vertical, 4)
        }
        .transitionSource(id: item.product.id, namespace: namespace)
    }
} 
