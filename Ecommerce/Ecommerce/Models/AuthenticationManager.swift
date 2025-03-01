import Foundation
import Networking

@Observable
public final class AuthenticationManager {
    private let authService: any AuthenticationServiceProtocol
    private let userService: any UserServiceProtocol
    private let tokenStore: TokenStoreProtocol
    private let dateFormatter = ISO8601DateFormatter()
    
    public var currentUser: UserResponse?
    public var isAuthenticated = false
    public var isLoading = false
    public var error: Error?
    
    public init(
        authService: any AuthenticationServiceProtocol,
        userService: any UserServiceProtocol,
        tokenStore: TokenStoreProtocol
    ) {
        self.authService = authService
        self.userService = userService
        self.tokenStore = tokenStore
        
        // Check token validity on init
        Task {
            await validateSession()
        }
    }
    
    private func createToken(from response: AuthResponse) -> Token {
        return Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expirationDate: dateFormatter.date(from: response.expiresAt)
        )
    }
    
    public func validateSession() async {
        isLoading = true
        do {
            if let token = try await tokenStore.getToken() {
                if token.isAccessTokenValid {
                    isAuthenticated = true
                    await loadProfile()
                } else if !token.refreshToken.isEmpty {
                    // Try to refresh the token
                    let authResponse = try await authService.refreshToken(token.refreshToken)
                    let newToken = createToken(from: authResponse)
                    try await tokenStore.setToken(newToken)
                    isAuthenticated = true
                    currentUser = authResponse.user
                } else {
                    // Invalid token, clean up
                    await tokenStore.deleteToken()
                    isAuthenticated = false
                    currentUser = nil
                }
            }
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
            await tokenStore.deleteToken()
        }
        isLoading = false
    }
    
    @MainActor
    public func signIn(identifier: String, password: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await authService.login(dto: LoginRequest(
                identifier: identifier,
                password: password
            ))
            
            let token = createToken(from: response)
            try await tokenStore.setToken(token)
            currentUser = response.user
            isAuthenticated = true
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
        }
        
        isLoading = false
    }
    
    public func register(username: String, displayName: String, email: String, password: String) async {
        isLoading = true
        error = nil
        do {
            let dto = CreateUserRequest(
                username: username,
                displayName: displayName,
                email: email,
                password: password
            )
            let authResponse = try await authService.register(dto: dto)
            let token = createToken(from: authResponse)
            try await tokenStore.setToken(token)
            isAuthenticated = true
            currentUser = authResponse.user
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func signOut() async {
        isLoading = true
        error = nil
        do {
            // Clear token and cached data
            try await tokenStore.invalidateToken()
            URLCache.shared.removeAllCachedResponses()
            
            // Clear state
            currentUser = nil
            isAuthenticated = false
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    func loadProfile() async {
        guard isAuthenticated else { return }
        isLoading = true
        error = nil
        do {
            currentUser = try await userService.getProfile()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func updateProfile(displayName: String, email: String? = nil) async {
        guard let id = currentUser?.id else { return }
        isLoading = true
        error = nil
        do {
            let dto = UpdateUserRequest(displayName: displayName, email: email)
            currentUser = try await userService.updateUser(id: id, dto: dto)
            
            // If email was updated, we need to update the JWT since it uses email as subject
            if let newEmail = email {
                // Re-login to get new tokens with updated email
                let loginDTO = LoginRequest(identifier: newEmail, password: "")  // Password not needed as we're already authenticated
                let response = try await authService.login(dto: loginDTO)
                try await tokenStore.setToken(createToken(from: response))
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func refreshProfile() async {
        do {
            currentUser = try await userService.getProfile()
        } catch {
            self.error = error
        }
    }
}
