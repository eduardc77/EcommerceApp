//
//  EcommerceApp.swift
//  Ecommerce
//

import SwiftUI
import Networking

@main
struct GenericNetworkingApp: App {
    @State private var authManager: AuthenticationManager
    @State private var categoryManager: CategoryManager
    @State private var productManager: ProductManager
    @State private var permissionManager: PermissionManager
    @State private var userManager: UserManager
    @State private var favoritesManager = FavoritesManager()
    @State private var cartManager = CartManager()
    @State private var toastManager = ToastManager()

    init() {
        let (auth, category, product, permission, user) = Self.setupManagers()

        _authManager = State(initialValue: auth)
        _categoryManager = State(initialValue: category)
        _productManager = State(initialValue: product)
        _permissionManager = State(initialValue: permission)
        _userManager = State(initialValue: user)
    }

    private static func setupManagers() -> (
        auth: AuthenticationManager,
        category: CategoryManager,
        product: ProductManager,
        permission: PermissionManager,
        user: UserManager
    ) {
        let tokenStore = TokenStore()
        let authorizationManager = AuthorizationManager(tokenStore: tokenStore)
        let apiClient = DefaultAPIClient(authorizationManager: authorizationManager)

        // Set the API client after creation
        Task {
            await authorizationManager.setAPIClient(apiClient)
        }

        let authService = AuthenticationService(apiClient: apiClient)
        let userService = UserService(apiClient: apiClient)
        let categoryService = CategoryService(apiClient: apiClient)
        let productService = ProductService(apiClient: apiClient)

        let auth = AuthenticationManager(
            authService: authService,
            userService: userService,
            tokenStore: tokenStore
        )

        let category = CategoryManager(
            categoryService: categoryService
        )

        let product = ProductManager(
            productService: productService,
            categoryService: categoryService
        )

        let permission = PermissionManager(
            authManager: auth
        )

        let user = UserManager(userService: userService)

        return (auth, category, product, permission, user)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(categoryManager)
                .environment(productManager)
                .environment(permissionManager)
                .environment(userManager)
                .environment(favoritesManager)
                .environment(cartManager)
                .environment(toastManager)
                .overlay {
                    ToastContainer()
                        .environment(toastManager)
                }
        }
    }
}
