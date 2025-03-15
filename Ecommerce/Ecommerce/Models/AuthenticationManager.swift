import Foundation
import Networking

// Login specific errors
public enum LoginError: LocalizedError {
    case invalidCredentials
    case accountNotFound
    case accountLocked
    case tooManyAttempts
    case requiresMFA
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountNotFound:
            return "No account found with this email"
        case .accountLocked:
            return "Your account has been locked. Please contact support"
        case .tooManyAttempts:
            return "Too many login attempts. Please try again later"
        case .requiresMFA:
            return "Multi-factor authentication is required"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let message):
            return message
        }
    }
}

// Registration specific errors
public enum RegistrationError: LocalizedError {
    case weakPassword
    case invalidEmail
    case accountExists
    case termsNotAccepted
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .weakPassword:
            return "Password must be at least 8 characters and include a number and special character"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .accountExists:
            return "An account with this email already exists"
        case .termsNotAccepted:
            return "You must accept the terms and conditions"
        case .unknown(let message):
            return message
        }
    }
}

// Email verification specific errors
public enum VerificationError: LocalizedError {
    case invalidCode
    case expiredCode
    case tooManyAttempts
    case emailNotFound
    case alreadyVerified
    case tooManyRequests
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid verification code"
        case .expiredCode:
            return "This code has expired. Please request a new one"
        case .tooManyAttempts:
            return "Too many invalid attempts. Please request a new code"
        case .emailNotFound:
            return "Email address not found"
        case .alreadyVerified:
            return "This email is already verified"
        case .tooManyRequests:
            return "Too many requests. Please try again later"
        case .unknown(let message):
            return message
        }
    }
}

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
    public var loginError: LoginError?
    public var registrationError: RegistrationError?
    public var verificationError: VerificationError?
    
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
                    // On initial load, we want to be strict about profile loading
                    isAuthenticated = true
                    do {
                        // Load profile directly here since we want stricter error handling
                        currentUser = try await userService.getProfile()
                        await check2FAStatus()
                        await checkEmailVerificationStatus()
                    } catch {
                        // On initial load, ANY profile error should reset auth state
                        self.error = error
                        isAuthenticated = false
                        currentUser = nil
                        await tokenStore.deleteToken()
                    }
                } else if !token.refreshToken.isEmpty {
                    // Try to refresh the token
                    let authResponse = try await authService.refreshToken(token.refreshToken)
                    let newToken = createToken(from: authResponse)
                    try await tokenStore.setToken(newToken)
                    isAuthenticated = true
                    currentUser = authResponse.user // Use user from refresh response
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
        loginError = nil // Clear previous login errors
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
            
            // No need to load profile here since we have it from login response
            await check2FAStatus()
            await checkEmailVerificationStatus()
            
        } catch let networkError as NetworkError {
            if case .unauthorized(let description) = networkError {
                if description.contains("2FA required") {
                    loginError = .requiresMFA
                    requires2FA = true
                } else {
                    loginError = .invalidCredentials
                }
            } else {
                loginError = .networkError(networkError.localizedDescription)
            }
            isAuthenticated = false
            currentUser = nil
        } catch {
            loginError = .unknown(error.localizedDescription)
            isAuthenticated = false
            currentUser = nil
        }
        
        isLoading = false
    }
    
    @MainActor
    public func register(username: String, displayName: String, email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        registrationError = nil // Clear previous registration errors
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
            
            // The initial verification code is already sent during registration
            // DO NOT send another code here
            
        } catch let networkError as NetworkError {
            if case .clientError(let statusCode, _) = networkError, statusCode == 409 {
                registrationError = .accountExists
            } else {
                registrationError = .unknown(networkError.localizedDescription)
            }
            isAuthenticated = false
            currentUser = nil
            try? await tokenStore.invalidateToken()
        } catch {
            registrationError = .unknown(error.localizedDescription)
            isAuthenticated = false
            currentUser = nil
            try? await tokenStore.invalidateToken()
        }
    }
    
    @MainActor
    public func signOut() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        
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
    }
    
    // MARK: - Profile Management
    
    @MainActor
    public func updateProfile(displayName: String, email: String? = nil, profilePicture: String? = nil) async {
        guard let id = currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }
        error = nil
        
        do {
            let dto = UpdateUserRequest(
                displayName: displayName,
                email: email,
                profilePicture: profilePicture
            )
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
    }
    
    @MainActor
    public func refreshProfile() async {
        guard isAuthenticated else { return }
        
        isLoading = true
        error = nil
        
        do {
            // Regular profile refresh - only clear auth on unauthorized
            currentUser = try await userService.getProfile()
            await check2FAStatus()
            await checkEmailVerificationStatus()
        } catch let networkError as NetworkError {
            self.error = networkError
            // Only clear auth state on auth errors during refresh
            if case .unauthorized = networkError {
                isAuthenticated = false
                currentUser = nil
                try? await tokenStore.invalidateToken()
            }
        } catch {
            // Keep existing profile data on other errors
            self.error = error
        }
        
        isLoading = false
    }
    
    // MARK: - Email Verification
    
    private func checkEmailVerificationStatus() async {
        do {
            let status = try await emailVerificationService.getInitialStatus()
            requiresEmailVerification = !status.verified
        } catch {
            self.error = error
        }
    }
    
    @MainActor
    public func verifyEmail(code: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        verificationError = nil // Clear previous verification errors
        
        do {
            guard let email = currentUser?.email else {
                verificationError = .emailNotFound
                return false
            }
            _ = try await emailVerificationService.verifyInitialEmail(email: email, code: code)
            requiresEmailVerification = false
            isAuthenticated = true // Set authentication state to true after successful verification
            return true
        } catch {
            if let verificationError = error as? VerificationError {
                self.verificationError = verificationError
            } else {
                verificationError = .unknown(error.localizedDescription)
            }
            return false
        }
    }
    
    func resendVerificationEmail() async {
        isLoading = true
        defer { isLoading = false }
        verificationError = nil // Clear previous verification errors
        
        do {
            guard let email = currentUser?.email else {
                verificationError = .emailNotFound
                return
            }
            _ = try await emailVerificationService.resendVerificationEmail(email: email)
        } catch {
            if let verificationError = error as? VerificationError {
                self.verificationError = verificationError
            } else {
                verificationError = .unknown(error.localizedDescription)
            }
        }
    }
    
    @MainActor
    public func skipEmailVerification() {
        // Allow access to the app but keep requiresEmailVerification true
        // so the verification section remains visible
        isAuthenticated = true
        requiresEmailVerification = true
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
        defer { isLoading = false }
        error = nil
        do {
            _ = try await emailVerificationService.setup2FA()
        } catch {
            self.error = error
        }
    }
    
    public func verify2FA(code: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        error = nil
        do {
            _ = try await emailVerificationService.verify2FA(code: code)
            requires2FA = true
            return true
        } catch {
            self.error = error
            return false
        }
    }
    
    public func disable2FA() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            _ = try await emailVerificationService.disable2FA()
            requires2FA = false
        } catch {
            self.error = error
        }
    }
}
