//
//  EcommerceApp.swift
//  Ecommerce
//

import SwiftUI
import Networking

@main
struct EcommerceApp: App {
    @State private var authManager: AuthenticationManager
    @State private var categoryManager: CategoryManager
    @State private var productManager: ProductManager
    @State private var permissionManager: PermissionManager
    @State private var userManager: UserManager
    @State private var favoritesManager = FavoritesManager()
    @State private var cartManager = CartManager()
    @State private var toastManager = ToastManager()
    @State private var totpManager: TOTPManager
    @State private var emailVerificationManager: EmailVerificationManager
    
    init() {
        // Initialize core networking
        let tokenStore = TokenStore()
        let authorizationManager = AuthorizationManager(tokenStore: tokenStore)
        let apiClient = DefaultAPIClient(authorizationManager: authorizationManager)
        
        // Set the API client after creation for token refresh
        Task {
            await authorizationManager.setAPIClient(apiClient)
        }
        
        // Initialize available services
        let authService = AuthenticationService(apiClient: apiClient)
        let userService = UserService(apiClient: apiClient)
        let totpService = TOTPService(apiClient: apiClient)
        let emailVerificationService = EmailVerificationService(apiClient: apiClient)
        let productService = ProductService(apiClient: apiClient)
        let categoryService = CategoryService(apiClient: apiClient)
        
        // Initialize managers
        let auth = AuthenticationManager(
            authService: authService,
            userService: userService,
            tokenStore: tokenStore,
            totpService: totpService,
            emailVerificationService: emailVerificationService
        )
        _authManager = State(initialValue: auth)
        
        _userManager = State(initialValue: UserManager(userService: userService))
        _productManager = State(initialValue: ProductManager(productService: productService, categoryService: categoryService))
        _categoryManager = State(initialValue: CategoryManager(categoryService: categoryService))
        _permissionManager = State(initialValue: PermissionManager(authManager: auth))
        _totpManager = State(initialValue: TOTPManager(totpService: totpService))
        _emailVerificationManager = State(initialValue: EmailVerificationManager(emailVerificationService: emailVerificationService))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(userManager)
                .environment(permissionManager)
                .environment(categoryManager)
                .environment(productManager)
                .environment(favoritesManager)
                .environment(cartManager)
                .environment(toastManager)
                .environment(totpManager)
                .environment(emailVerificationManager)
                .overlay {
                    ToastContainer()
                        .environment(toastManager)
                }
        }
    }
}
