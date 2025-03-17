import Foundation
import Networking

@Observable
@MainActor
public final class AuthenticationManager {
    private let authService: AuthenticationServiceProtocol
    private let userService: UserServiceProtocol
    private let authorizationManager: AuthorizationManagerProtocol
    private let totpManager: TOTPManager
    private let emailVerificationManager: EmailVerificationManager
    
    public var currentUser: UserResponse?
    public var isAuthenticated = false
    public var isLoading = false
    public var error: Error?
    public var loginError: LoginError?
    public var registrationError: RegistrationError?

    public init(
        authService: AuthenticationServiceProtocol,
        userService: UserServiceProtocol,
        totpManager: TOTPManager,
        emailVerificationManager: EmailVerificationManager,
        authorizationManager: AuthorizationManagerProtocol
    ) {
        self.authService = authService
        self.userService = userService
        self.totpManager = totpManager
        self.emailVerificationManager = emailVerificationManager
        self.authorizationManager = authorizationManager
        
        // Check token validity on init
        Task {
            await validateSession()
        }
    }
    
    public func validateSession() async {
        isLoading = true
        
        do {
            // Try to get a valid token (will refresh if needed)
            _ = try await authorizationManager.getValidToken()
            
            // Token is valid, load profile and check verification status
            isAuthenticated = true
            do {
                currentUser = try await userService.getProfile()
                await totpManager.getTOTPStatus()
                // Check email verification status
                await emailVerificationManager.getInitialStatus()
            } catch {
                // On initial load, ANY profile error should reset auth state
                self.error = error
                isAuthenticated = false
                currentUser = nil
                try? await authorizationManager.invalidateToken()
            }
        } catch {
            self.error = error
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
        }
        
        isLoading = false
    }
    
    @MainActor
    public func register(username: String, displayName: String, email: String, password: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        registrationError = nil // Clear previous registration errors
        isAuthenticated = false
        
        do {
            let dto = CreateUserRequest(
                username: username,
                displayName: displayName,
                email: email,
                password: password
            )
            
            let authResponse = try await authService.register(dto: dto)
            currentUser = authResponse.user
            
            // Set email verification state
            let requiresVerification = authResponse.requiresEmailVerification
            emailVerificationManager.requiresEmailVerification = requiresVerification
            
            // Set authenticated since registration was successful
            isAuthenticated = true
            
            return requiresVerification
            
        } catch let networkError as NetworkError {
            if case .clientError(let statusCode, let description, _) = networkError {
                switch statusCode {
                case 409:
                    registrationError = .accountExists
                case 422:
                    registrationError = .validationError(description)
                default:
                    registrationError = .unknown(description)
                }
            } else {
                registrationError = .unknown(networkError.localizedDescription)
            }
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
            return false
        } catch {
            registrationError = .unknown(error.localizedDescription)
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
            return false
        }
    }
    
    @MainActor
    public func signOut() async {
        isLoading = true
        error = nil
        
        do {
            // Clear token and cached data
            try await authorizationManager.invalidateToken()
            URLCache.shared.removeAllCachedResponses()
        } catch {
            self.error = error
        }
        
        // Reset all state regardless of token invalidation result
        currentUser = nil
        isAuthenticated = false
        loginError = nil
        registrationError = nil
        totpManager.reset()
        emailVerificationManager.reset()
        
        isLoading = false
    }
    
    @MainActor
    public func signIn(identifier: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        loginError = nil // Clear previous login errors
        isAuthenticated = false
        
        do {
            let dto = LoginRequest(identifier: identifier, password: password)
            let response = try await authService.login(dto: dto)
            currentUser = response.user
            
            // Set authenticated since login was successful
            isAuthenticated = true
            
            // Check verification and TOTP status in background
            Task {
                await emailVerificationManager.getInitialStatus()
                await totpManager.getTOTPStatus()
            }
        } catch let networkError as NetworkError {
            if case .clientError(let statusCode, _, let headers) = networkError {
                switch statusCode {
                case 423:
                    loginError = .accountLocked(retryAfter: nil)
                case 429:
                    if let retryAfter = headers["Retry-After"].flatMap(Int.init) {
                        loginError = .accountLocked(retryAfter: retryAfter)
                    } else {
                        loginError = .accountLocked(retryAfter: 900) // Default to 15 minutes
                    }
                case 401:
                    loginError = .invalidCredentials
                default:
                    loginError = .unknown(networkError.localizedDescription)
                }
            } else {
                loginError = .unknown(networkError.localizedDescription)
            }
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
        } catch {
            loginError = .unknown(error.localizedDescription)
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
        }
    }
    
    // MARK: - Profile Management
    
    @MainActor
    public func updateProfile(displayName: String, email: String? = nil, profilePicture: String? = nil) async -> String? {
        guard let id = currentUser?.id else { return nil }
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
                currentUser = response.user
                return newEmail // Return the new email if it was updated
            }
            return nil
        } catch {
            self.error = error
            return nil
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
            await totpManager.getTOTPStatus()
        } catch let networkError as NetworkError {
            self.error = networkError
            // Only clear auth state on auth errors during refresh
            if case .unauthorized = networkError {
                isAuthenticated = false
                currentUser = nil
                try? await authorizationManager.invalidateToken()
            }
        } catch {
            // Keep existing profile data on other errors
            self.error = error
        }
        isLoading = false
    }
}
