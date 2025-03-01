import Foundation

enum AppTab: Hashable {
    case home
    case products
    case cart
    case favorites
    case users
    
    var title: String {
        switch self {
        case .home: "Home"
        case .products: "Products"
        case .cart: "Cart"
        case .favorites: "Favorites"
        case .users: "Users"
        }
    }
    
    var icon: String {
        switch self {
        case .home: "house"
        case .products: "square.grid.2x2"
        case .cart: "cart"
        case .favorites: "heart"
        case .users: "person.2"
        }
    }
    
    var customizationID: String {
        switch self {
        case .home: "home.tab"
        case .products: "products.tab"
        case .cart: "cart.tab"
        case .favorites: "favorites.tab"
        case .users: "users.tab"
        }
    }
} 
