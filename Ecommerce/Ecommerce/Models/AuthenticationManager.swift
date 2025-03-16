import Foundation
import Networking

@Observable
public final class AuthenticationManager {
    private let authService: AuthenticationServiceProtocol
    private let userService: UserServiceProtocol
    private let totpService: TOTPServiceProtocol
    private let emailVerificationService: EmailVerificationServiceProtocol
    private let authorizationManager: AuthorizationManagerProtocol
    
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
        totpService: TOTPServiceProtocol,
        emailVerificationService: EmailVerificationServiceProtocol,
        authorizationManager: AuthorizationManagerProtocol
    ) {
        self.authService = authService
        self.userService = userService
        self.totpService = totpService
        self.emailVerificationService = emailVerificationService
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
            
            // Token is valid, load profile
            isAuthenticated = true
            do {
                currentUser = try await userService.getProfile()
                await check2FAStatus()
                await checkEmailVerificationStatus()
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
    public func signIn(identifier: String, password: String, totpCode: String? = nil) async {
        isLoading = true
        loginError = nil
        isAuthenticated = false
        
        do {
            let response = try await authService.login(dto: LoginRequest(
                identifier: identifier,
                password: password,
                totpCode: totpCode,
                emailCode: nil
            ))
            
            currentUser = response.user
            isAuthenticated = true
            
            await check2FAStatus()
            await checkEmailVerificationStatus()
            
        } catch let networkError as NetworkError {
            isAuthenticated = false
            currentUser = nil
            
            loginError = {
                switch networkError {
                case .unauthorized(let description):
                    if description.contains("2FA required") {
                        requires2FA = true
                        return .requiresMFA
                    }
                    return .invalidCredentials
                    
                case .notFound:
                    return .accountNotFound
                    
                case .forbidden(let description):
                    if description.contains("locked") {
                        return .accountLocked(retryAfter: nil)
                    }
                    return .unknown(description)
                    
                case .clientError(let statusCode, let description, let headers):
                    switch statusCode {
                    case 429:
                        if let retryAfterHeader = headers.first(where: { $0.key.lowercased() == "retry-after" })?.value,
                           let retryAfter = Int(retryAfterHeader) {
                            return .accountLocked(retryAfter: retryAfter)
                        }
                        return .tooManyAttempts // If no Retry-After header, show generic message
                    case 423:
                        return .accountLocked(retryAfter: nil)
                    default:
                        return .unknown(description)
                    }
                    
                case .missingToken:
                    return .invalidCredentials
                    
                case .timeout:
                    return .networkError("Request timed out. Please check your connection and try again")
                    
                case .networkConnectionLost,
                     .dnsLookupFailed,
                     .cannotFindHost,
                     .cannotConnectToHost:
                    return .networkError("Cannot connect to server. Please check your internet connection")
                    
                case .internalServerError,
                     .serviceUnavailable,
                     .badGateway,
                     .gatewayTimeout:
                    return .serverError("Server is temporarily unavailable. Please try again later")
                    
                default:
                    return .unknown(networkError.localizedDescription)
                }
            }()
            
        } catch {
            isAuthenticated = false
            currentUser = nil
            loginError = .unknown(error.localizedDescription)
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
            currentUser = authResponse.user
            requiresEmailVerification = authResponse.requiresEmailVerification
            
            // Only set isAuthenticated if email verification is not required
            if !requiresEmailVerification {
                isAuthenticated = true
            }

        } catch let networkError as NetworkError {
            if case .clientError(let statusCode, _, _) = networkError, statusCode == 409 {
                registrationError = .accountExists
            } else {
                registrationError = .unknown(networkError.localizedDescription)
            }
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
        } catch {
            registrationError = .unknown(error.localizedDescription)
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
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
            try await authorizationManager.invalidateToken()
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
                currentUser = response.user
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
                try? await authorizationManager.invalidateToken()
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
