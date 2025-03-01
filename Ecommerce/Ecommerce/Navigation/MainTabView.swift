import SwiftUI
import Networking

struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @Environment(CartManager.self) private var cartManager

#if !os(macOS) && !os(tvOS)
    @AppStorage("sidebarCustomizations") private var tabViewCustomization: TabViewCustomization
#endif
    @Environment(\.horizontalSizeClass) private var horizontalSize

    var body: some View {
        TabView(selection: $selectedTab) {
            TabSection("Store") {
                Tab(AppTab.home.title, systemImage: AppTab.home.icon, value: AppTab.home) {
                    HomeView()
                }
                .customizationID(AppTab.home.customizationID)
#if !os(macOS) && !os(tvOS)
                .customizationBehavior(.disabled, for: .sidebar, .tabBar)
#endif

                Tab(AppTab.products.title, systemImage: AppTab.products.icon, value: AppTab.products) {
                    ProductsView()
                }
                .customizationID(AppTab.products.customizationID)
#if !os(macOS) && !os(tvOS)
                .customizationBehavior(.disabled, for: .sidebar, .tabBar)
#endif
            }

            Tab(AppTab.cart.title, systemImage: AppTab.cart.icon, value: AppTab.cart) {
                CartView()
            }
            .customizationID(AppTab.cart.customizationID)
            .badge(cartManager.items.isEmpty ? 0 : cartManager.items.count)
#if !os(macOS) && !os(tvOS)
            .customizationBehavior(.disabled, for: .sidebar, .tabBar)
#endif

            TabSection("Personal") {
                Tab(AppTab.favorites.title, systemImage: AppTab.favorites.icon, value: AppTab.favorites) {
                    FavoritesView()
                }
                .customizationID(AppTab.favorites.customizationID)
#if !os(macOS) && !os(tvOS)
                .customizationBehavior(.disabled, for: .sidebar, .tabBar)
#endif
                Tab(AppTab.users.title, systemImage: AppTab.users.icon, value: AppTab.users) {
                    UsersView()
                }
                .customizationID(AppTab.users.customizationID)
#if !os(macOS) && !os(tvOS)
                .customizationBehavior(.disabled, for: .sidebar, .tabBar)
#endif
            }
            .customizationID("personal.section")
        }
        .tabViewStyle(.sidebarAdaptable)
#if !os(macOS) && !os(tvOS)
        .tabViewCustomization($tabViewCustomization)
#endif
    }
}

#Preview {
    MainTabView()
        .environment(ProductManager(
            productService: ProductService(apiClient: PreviewAPIClient()),
            categoryService: CategoryService(apiClient: PreviewAPIClient())
        ))
        .environment(CategoryManager(
            categoryService: CategoryService(apiClient: PreviewAPIClient())
        ))
        .environment(UserManager(
            userService: PreviewUserService()
        ))
        .environment(AuthenticationManager(
            authService: PreviewAuthenticationService(),
            userService: PreviewUserService(),
            tokenStore: PreviewTokenStore()
        ))
        .environment(PermissionManager(
            authManager: AuthenticationManager(
                authService: PreviewAuthenticationService(),
                userService: PreviewUserService(),
                tokenStore: PreviewTokenStore()
            )
        ))
        .environment(CartManager())
}
