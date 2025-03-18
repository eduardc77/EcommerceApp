import Foundation
import Networking

enum AuthenticationError: Error {
    case noLoginInProgress
    case invalidTOTPToken
    case invalidCredentials
    case networkError(Error)
    case invalidResponse
    case serverError(String)
}

@Observable
@MainActor
public final class AuthenticationManager {
    private let authService: AuthenticationServiceProtocol
    private let userService: UserServiceProtocol
    private let authorizationManager: AuthorizationManagerProtocol
    public let totpManager: TOTPManager
    private let emailVerificationManager: EmailVerificationManager
    
    public var currentUser: UserResponse?
    public var isAuthenticated = false
    public var isLoading = false
    public var error: Error?
    public var loginError: LoginError?
    public var registrationError: RegistrationError?
    public var requiresTOTPVerification = false
    private var pendingLoginResponse: AuthResponse?
    private var pendingCredentials: (identifier: String, password: String)?
    
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
            
            let authResponse = try await authService.register(request: dto)
            currentUser = authResponse.user
            
            // Set email verification state
            let requiresVerification = authResponse.requiresEmailVerification
            emailVerificationManager.requiresEmailVerification = requiresVerification
            
            return requiresVerification
            
        } catch let networkError as NetworkError {
            switch networkError {
            case let .clientError(statusCode, description, _, _):
                switch statusCode {
                case 409:
                    registrationError = .accountExists
                case 422:
                    registrationError = .validationError(description)
                default:
                    registrationError = .unknown(description)
                }
            default:
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
    
    public func signIn(identifier: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        loginError = nil // Clear previous login errors
        isAuthenticated = false
        pendingLoginResponse = nil
        
        do {
            let dto = LoginRequest(identifier: identifier, password: password)
            let response = try await authService.login(request: dto)
            
            // Check if TOTP verification is required
            if response.requiresTOTP {
                requiresTOTPVerification = true
                pendingLoginResponse = response
                // Store credentials for TOTP verification
                self.pendingCredentials = (identifier: identifier, password: password)
                return
            }
            
            // Complete login if no TOTP required
            requiresTOTPVerification = false
            await completeLogin(response: response)
            
        } catch let networkError as NetworkError {
            switch networkError {
            case let .clientError(statusCode, _, headers, data):
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
                    // Check if this is a TOTP required response
                    if let data = data,
                       let response = try? JSONDecoder().decode(AuthResponse.self, from: data),
                       response.requiresTOTP {
                        // Handle TOTP requirement without setting error state
                        requiresTOTPVerification = true
                        pendingLoginResponse = response
                        return
                    } else {
                        loginError = .invalidCredentials
                    }
                default:
                    loginError = .unknown(networkError.localizedDescription)
                }
            default:
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
    
    public func verifyTOTPForLogin(code: String) async throws {
        guard let pendingLoginResponse = pendingLoginResponse else {
            throw AuthenticationError.noLoginInProgress
        }
        
        guard let tempToken = pendingLoginResponse.tempToken else {
            throw AuthenticationError.invalidTOTPToken
        }
        
        let response = try await authService.verifyTOTPLogin(
            tempToken: tempToken,
            code: code
        )
        
        // Clear pending state
        self.pendingLoginResponse = nil
        
        // Update login state with verified response
        updateLoginState(response: response)
    }
    
    private func completeLogin(response: AuthResponse) async {
        currentUser = response.user
        isAuthenticated = true
        
        // Check verification and TOTP status in background
        Task {
            await emailVerificationManager.getInitialStatus()
            await totpManager.getTOTPStatus()
        }
    }
    
    private func updateLoginState(response: AuthResponse) {
        currentUser = response.user
        isAuthenticated = true
    }
    
    // MARK: - Profile Management
    
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
                let response = try await authService.login(request: loginDTO)
                currentUser = response.user
                return newEmail // Return the new email if it was updated
            }
            return nil
        } catch {
            self.error = error
            return nil
        }
    }
    
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
