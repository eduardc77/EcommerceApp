//
//  EcommerceApp.swift
//  Ecommerce
//

import SwiftUI
import Networking
import GoogleSignIn

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
    @State private var recoveryCodesManager: RecoveryCodesManager
    @State private var socialAuthManager: SocialAuthManager
    
    init() {
        // Initialize core networking
        let tokenStore = TokenStore()
        let refreshClient = RefreshAPIClient(environment: .develop)
        
        // Create authorization manager first
        let authorizationManager = AuthorizationManager(
            refreshClient: refreshClient,
            tokenStore: tokenStore
        )
        
        // Create API client with authorization manager
        let apiClient = DefaultAPIClient(authorizationManager: authorizationManager)
        
        // Initialize available services
        let authService = AuthenticationService(
            apiClient: apiClient,
            authorizationManager: authorizationManager
        )
        let userService = UserService(apiClient: apiClient)
        let totpService = TOTPService(apiClient: apiClient)
        let emailVerificationService = EmailVerificationService(apiClient: apiClient)
        let productService = ProductService(apiClient: apiClient)
        let categoryService = CategoryService(apiClient: apiClient)
        let recoveryCodesService = RecoveryCodesService(apiClient: apiClient)
        
        // Create managers that don't have dependencies
        let totpManager = TOTPManager(totpService: totpService)
        let emailVerificationManager = EmailVerificationManager(emailVerificationService: emailVerificationService)
        let recoveryCodesManager = RecoveryCodesManager(recoveryCodesService: recoveryCodesService)
        
        // Create auth manager with all dependencies
        let auth = AuthenticationManager(
            authService: authService,
            userService: userService,
            totpManager: totpManager,
            emailVerificationManager: emailVerificationManager,
            recoveryCodesManager: recoveryCodesManager,
            authorizationManager: authorizationManager
        )
        
        // Initialize Google Sign-In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: AnyObject],
              let clientID = dict["CLIENT_ID"] as? String else {
            fatalError("Couldn't find GoogleService-Info.plist or CLIENT_ID in it")
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        
        // Initialize @State properties
        _authManager = State(initialValue: auth)
        _userManager = State(initialValue: UserManager(userService: userService))
        _productManager = State(initialValue: ProductManager(
            productService: productService,
            categoryService: categoryService
        ))
        _categoryManager = State(initialValue: CategoryManager(categoryService: categoryService))
        _totpManager = State(initialValue: totpManager)
        _emailVerificationManager = State(initialValue: emailVerificationManager)
        _permissionManager = State(initialValue: PermissionManager(authManager: auth))
        _recoveryCodesManager = State(initialValue: recoveryCodesManager)
        _socialAuthManager = State(initialValue: SocialAuthManager(authManager: auth))
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authManager)
                .environment(userManager)
                .environment(productManager)
                .environment(categoryManager)
                .environment(permissionManager)
                .environment(cartManager)
                .environment(favoritesManager)
                .environment(toastManager)
                .environment(totpManager)
                .environment(emailVerificationManager)
                .environment(recoveryCodesManager)
                .environment(socialAuthManager)
                .overlay {
                    ToastContainer()
                        .environment(toastManager)
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
