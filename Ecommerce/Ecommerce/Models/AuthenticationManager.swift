import Foundation
import Networking

@Observable
public final class AuthenticationManager {
    private let authService: AuthenticationServiceProtocol
    private let userService: UserServiceProtocol
    private let tokenStore: TokenStoreProtocol
    private let totpService: TOTPServiceProtocol
    private let emailVerificationService: EmailVerificationServiceProtocol
    private let dateFormatter = ISO8601DateFormatter()
    
    public var currentUser: UserResponse?
    public var isAuthenticated = false
    public var isLoading = false
    public var error: Error?
    public var requires2FA = false
    public var requiresEmailVerification = false
    
    public init(
        authService: AuthenticationServiceProtocol,
        userService: UserServiceProtocol,
        tokenStore: TokenStoreProtocol,
        totpService: TOTPServiceProtocol,
        emailVerificationService: EmailVerificationServiceProtocol
    ) {
        self.authService = authService
        self.userService = userService
        self.tokenStore = tokenStore
        self.totpService = totpService
        self.emailVerificationService = emailVerificationService
        
        // Check token validity on init
        Task {
            await validateSession()
        }
    }
    
    private func createToken(from response: AuthResponse) -> Token {
        Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            expiresAt: response.expiresAt
        )
    }
    
    public func validateSession() async {
        isLoading = true
        do {
            if let token = try await tokenStore.getToken() {
                if token.isAccessTokenValid {
                    isAuthenticated = true
                    await loadProfile()
                    await check2FAStatus()
                    await checkEmailVerificationStatus()
                } else if !token.refreshToken.isEmpty {
                    // Try to refresh the token
                    let authResponse = try await authService.refreshToken(token.refreshToken)
                    let newToken = createToken(from: authResponse)
                    try await tokenStore.setToken(newToken)
                    isAuthenticated = true
                    currentUser = authResponse.user
                    await check2FAStatus()
                    await checkEmailVerificationStatus()
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
    public func signIn(identifier: String, password: String, totpCode: String? = nil) async {
        isLoading = true
        error = nil
        isAuthenticated = false
        
        do {
            let response = try await authService.login(dto: LoginRequest(
                identifier: identifier,
                password: password,
                totpCode: totpCode,
                emailCode: nil
            ))
            
            let token = createToken(from: response)
            try await tokenStore.setToken(token)
            
            currentUser = response.user
            isAuthenticated = true
            
            await check2FAStatus()
            await checkEmailVerificationStatus()
            
        } catch let networkError as NetworkError {
            self.error = networkError
            if case .unauthorized(let description) = networkError, description.contains("2FA required") {
                requires2FA = true
            }
            isAuthenticated = false
            currentUser = nil
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
        }
        
        isLoading = false
    }
    
    @MainActor
    public func register(username: String, displayName: String, email: String, password: String) async {
        isLoading = true
        error = nil
        isAuthenticated = false
        requiresEmailVerification = false
        
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
            
            currentUser = authResponse.user
            requiresEmailVerification = authResponse.requiresEmailVerification
            
            // Only set isAuthenticated if email verification is not required
            if !requiresEmailVerification {
                isAuthenticated = true
            }
            
            // If email verification is required, send the initial code
            if requiresEmailVerification {
                _ = try? await emailVerificationService.setup2FA()
            }
            
        } catch let networkError as NetworkError {
            self.error = networkError
            isAuthenticated = false
            currentUser = nil
            try? await tokenStore.invalidateToken()
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
            try? await tokenStore.invalidateToken()
        }
        
        isLoading = false
    }
    
    @MainActor
    public func signOut() async {
        isLoading = true
        error = nil
        
        do {
            // Clear local state first
            isAuthenticated = false
            currentUser = nil
            requires2FA = false
            requiresEmailVerification = false
            
            // Clear token and cached data
            try await tokenStore.invalidateToken()
            URLCache.shared.removeAllCachedResponses()
            
            // Call backend logout endpoint last
            // If this fails, we're already logged out locally
            try? await authService.logout()
            
        } catch {
            // Even if there's an error, we want to ensure we're logged out locally
            isAuthenticated = false
            currentUser = nil
            requires2FA = false
            requiresEmailVerification = false
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Profile Management
    
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
    
    @MainActor
    public func updateProfile(displayName: String, email: String? = nil) async {
        guard let id = currentUser?.id else { return }
        isLoading = true
        error = nil
        
        do {
            let dto = UpdateUserRequest(displayName: displayName, email: email)
            currentUser = try await userService.updateProfile(id: id, dto: dto)
            
            // If email was updated, we need to update the JWT since it uses email as subject
            if let newEmail = email {
                // Reauthenticate to get new tokens with updated email
                let loginDTO = LoginRequest(identifier: newEmail, password: "") // Password not needed as we're already authenticated
                let response = try await authService.login(dto: loginDTO)
                try await tokenStore.setToken(createToken(from: response))
            }
            
            // Send verification email for new address
            if email != nil {
                _ = try await emailVerificationService.setup2FA()
                requiresEmailVerification = true
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
            await check2FAStatus()
            await checkEmailVerificationStatus()
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Email Verification
    
    private func checkEmailVerificationStatus() async {
        do {
            let status = try await emailVerificationService.getInitialStatus()
            requiresEmailVerification = !status.verified
        } catch {
            // Don't update UI state for email verification check failures
        }
    }
    
    @MainActor
    public func verifyEmail(code: String) async -> Bool {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            if let email = currentUser?.email {
                _ = try await emailVerificationService.verifyInitialEmail(email: email, code: code)
                requiresEmailVerification = false
                isAuthenticated = true
                return true
            }
            return false
        } catch {
            self.error = error
            return false
        }
    }
    
    public func resendVerificationEmail() async {
        isLoading = true
        error = nil
        do {
            if let email = currentUser?.email {
                _ = try await emailVerificationService.resendVerificationEmail(email: email)
            }
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func skipEmailVerification() {
        requiresEmailVerification = false
        isAuthenticated = true
    }
    
    // MARK: - 2FA Management
    
    private func check2FAStatus() async {
        do {
            let status = try await emailVerificationService.get2FAStatus()
            requires2FA = status.enabled
        } catch {
            // Don't update UI state for 2FA check failures
        }
    }
    
    public func setup2FA() async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.setup2FA()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func verify2FA(code: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.verify2FA(code: code)
            requires2FA = true
            isLoading = false
            return true
        } catch {
            self.error = error
            isLoading = false
            return false
        }
    }
    
    public func disable2FA() async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.disable2FA()
            requires2FA = false
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
