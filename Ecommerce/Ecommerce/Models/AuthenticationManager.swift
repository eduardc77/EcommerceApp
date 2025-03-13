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
            expirationDate: ISO8601DateFormatter().date(from: response.expiresAt) ?? Date().addingTimeInterval(TimeInterval(response.expiresIn))
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
            
            // Check 2FA and email verification status
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
            
            // Send verification email
            _ = try await emailVerificationService.sendCode()
            requiresEmailVerification = true
            
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
            isAuthenticated = false
            currentUser = nil
            requires2FA = false
            requiresEmailVerification = false
            
        } catch {
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
            currentUser = try await userService.updateUser(id: id, dto: dto)
            
            // If email was updated, we need to update the JWT since it uses email as subject
            if let newEmail = email {
                // Reauthenticate to get new tokens with updated email
                let loginDTO = LoginRequest(identifier: newEmail, password: "") // Password not needed as we're already authenticated
                let response = try await authService.login(dto: loginDTO)
                try await tokenStore.setToken(createToken(from: response))
            }
            
            // Send verification email for new address
            if email != nil {
                _ = try await emailVerificationService.sendCode()
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
    
    // MARK: - 2FA Management
    
    private func check2FAStatus() async {
        do {
            let status = try await totpService.getStatus()
            requires2FA = status.enabled
        } catch {
            // Don't update UI state for 2FA check failures
            print("Failed to check 2FA status: \(error)")
        }
    }
    
    public func setup2FA() async -> String? {
        isLoading = true
        error = nil
        do {
            let response = try await totpService.setup()
            isLoading = false
            return response.qrCodeUrl
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    public func verify2FA(code: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.verify(code: code)
            isLoading = false
            return true
        } catch {
            self.error = error
            isLoading = false
            return false
        }
    }
    
    public func enable2FA(code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.enable(code: code)
            requires2FA = true
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    public func disable2FA(code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.disable(code: code)
            requires2FA = false
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    // MARK: - Email Verification
    
    private func checkEmailVerificationStatus() async {
        do {
            let status = try await emailVerificationService.getStatus()
            requiresEmailVerification = !status.verified
        } catch {
            // Don't update UI state for email verification check failures
            print("Failed to check email verification status: \(error)")
        }
    }
    
    public func verifyEmail(code: String) async -> Bool {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.verify(code: code)
            requiresEmailVerification = false
            isLoading = false
            return true
        } catch {
            self.error = error
            isLoading = false
            return false
        }
    }
    
    public func resendVerificationEmail() async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.sendCode()
        } catch {
            self.error = error
        }
        isLoading = false
    }
}
