import SwiftUI
import Networking

struct ProductRow: View {
    let product: ProductResponse
    let namespace: Namespace.ID

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: product.images.first ?? "")) { image in
                image.resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
            } placeholder: {
                Color.gray.opacity(0.2)
                    .frame(width: 60, height: 60)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading) {
                Text(product.title)
                    .font(.headline)
                Text(product.price.formatted(.currency(code: "USD")))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                FavoriteButton(product: product)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
                
                AddToCartButton(product: product)
                    .padding(4)
                    .background(.ultraThinMaterial)
                    .clipShape(.circle)
            }
        }
        .transitionSource(id: product.id, namespace: namespace)
    }
} 
