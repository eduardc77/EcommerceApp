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
        
        // Initialize auth manager with new services
        let auth = AuthenticationManager(
            authService: authService,
            userService: userService,
            tokenStore: tokenStore,
            totpService: totpService,
            emailVerificationService: emailVerificationService
        )
        _authManager = State(initialValue: auth)
        
        // Initialize user manager
        _userManager = State(initialValue: UserManager(userService: userService))
        
        // Initialize permission manager
        _permissionManager = State(initialValue: PermissionManager(authManager: auth))
        
        // Initialize managers with mock services for now
        _categoryManager = State(initialValue: CategoryManager())  // Using mock implementation
        _productManager = State(initialValue: ProductManager())   // Using mock implementation
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
