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
    public var requires2FAEmailVerification = false
    var pendingLoginResponse: AuthResponse?
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
            
            // Load profile and check verification status first
            do {
                currentUser = try await userService.getProfile()
                await totpManager.getTOTPStatus()
                // Check email verification status
                try await emailVerificationManager.getInitialStatus()
                
                // Only set authenticated if no 2FA methods are enabled
                if !totpManager.isEnabled && !emailVerificationManager.is2FAEnabled {
                    isAuthenticated = true
                }
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
    
    private func handleLoginError(_ error: Error) async {
        if let networkError = error as? NetworkError {
            switch networkError {
            case let .clientError(statusCode, _, headers, data):
                switch statusCode {
                case 423:
                    loginError = .accountLocked(retryAfter: nil)
                case 429:
                    let retryAfter = headers["Retry-After"].flatMap(Int.init) ?? 900 // Default to 15 minutes
                    loginError = .accountLocked(retryAfter: retryAfter)
                case 401:
                    // Check if this is a TOTP required response
                    if let data = data,
                       let response = try? JSONDecoder().decode(AuthResponse.self, from: data),
                       response.requiresTOTP {
                        // Handle TOTP requirement without setting error state
                        requiresTOTPVerification = true
                        pendingLoginResponse = response
                        return
                    }
                    loginError = .invalidCredentials
                default:
                    loginError = .unknown(networkError.localizedDescription)
                }
            default:
                loginError = .unknown(networkError.localizedDescription)
            }
        } else {
            loginError = .unknown(error.localizedDescription)
        }
        
        isAuthenticated = false
        currentUser = nil
        try? await authorizationManager.invalidateToken()
    }

    public func signIn(identifier: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        
        // Reset state
        loginError = nil
        isAuthenticated = false
        pendingLoginResponse = nil
        requiresTOTPVerification = false
        requires2FAEmailVerification = false
        
        do {
            let dto = LoginRequest(identifier: identifier, password: password)
            let response = try await authService.login(request: dto)
            
            if response.requiresTOTP || response.requiresEmailVerification {
                pendingLoginResponse = response
                self.pendingCredentials = (identifier: identifier, password: password)
                requiresTOTPVerification = response.requiresTOTP
                requires2FAEmailVerification = response.requiresEmailVerification
                currentUser = response.user
                isAuthenticated = false
                return
            }
            
            await completeLogin(response: response)
        } catch {
            await handleLoginError(error)
        }
    }
    
    /// Sign in with Google
    /// - Parameters:
    ///   - idToken: The ID token received from Google Sign-In
    ///   - accessToken: The access token received from Google Sign-In (optional)
    public func signInWithGoogle(idToken: String, accessToken: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        // Reset state
        loginError = nil
        isAuthenticated = false
        pendingLoginResponse = nil
        
        do {
            let response = try await authService.loginWithGoogle(idToken: idToken, accessToken: accessToken)
            await completeLogin(response: response)
        } catch {
            await handleLoginError(error)
        }
    }
    
    /// Sign in with Apple
    /// - Parameters:
    ///   - identityToken: The identity token string from Sign in with Apple
    ///   - authorizationCode: The authorization code from Sign in with Apple
    ///   - fullName: User's name components (optional, only provided on first login)
    ///   - email: User's email (optional, only provided on first login)
    public func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]? = nil,
        email: String? = nil
    ) async {
        isLoading = true
        defer { isLoading = false }
        
        // Reset state
        loginError = nil
        isAuthenticated = false
        pendingLoginResponse = nil
        
        do {
            let response = try await authService.loginWithApple(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                fullName: fullName,
                email: email
            )
            await completeLogin(response: response)
        } catch {
            await handleLoginError(error)
        }
    }
    
    private func completeLogin(response: AuthResponse) async {
        currentUser = response.user
        
        if response.requiresTOTP || response.requiresEmailVerification {
            // Store pending state and set flags for required verification
            pendingLoginResponse = response
            requiresTOTPVerification = response.requiresTOTP
            requires2FAEmailVerification = response.requiresEmailVerification
            isAuthenticated = false
        } else {
            // Complete authentication if no verification required
            pendingLoginResponse = nil
            requiresTOTPVerification = false
            requires2FAEmailVerification = false
            isAuthenticated = true
            await storeTokenAndUpdateStatus(response)
        }
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

    // MARK: - Helpers
    
    private func storeTokenAndUpdateStatus(_ response: AuthResponse) async {
        let token = Token(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            tokenType: response.tokenType,
            expiresIn: response.expiresIn,
            expiresAt: response.expiresAt
        )
        await authorizationManager.storeToken(token)
        
        // Update verification statuses in background
        Task {
            try await emailVerificationManager.getInitialStatus()
            await totpManager.getTOTPStatus()
        }
    }

    public func verifyTOTPForLogin(code: String, tempToken: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        let response = try await authService.verifyTOTPLogin(code: code, tempToken: tempToken)
        
        // Update user data
        currentUser = response.user
        requiresTOTPVerification = false
        
        if response.requiresEmailVerification {
            // Store temp token and set state for email verification
            pendingLoginResponse = response
            requires2FAEmailVerification = true
            isAuthenticated = false
            
            // Request initial email code using the new temp token
            try await requestEmailCode(tempToken: response.tempToken ?? "")
        } else {
            // Complete authentication if no email verification needed
            pendingLoginResponse = nil
            requires2FAEmailVerification = false
            isAuthenticated = true
            await storeTokenAndUpdateStatus(response)
        }
    }
    
    public func verifyEmail2FALogin(code: String, tempToken: String) async throws {
        guard pendingLoginResponse != nil else {
            throw AuthenticationError.noLoginInProgress
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let response = try await authService.verifyEmail2FALogin(code: code, tempToken: tempToken)
        
        // Complete authentication
        currentUser = response.user
        isAuthenticated = true
        
        // Clear verification states
        self.pendingLoginResponse = nil
        requiresTOTPVerification = false
        requires2FAEmailVerification = false
        
        await storeTokenAndUpdateStatus(response)
    }

    /// Request a new email verification code during login
    public func requestEmailCode(tempToken: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await authService.requestEmailCode(tempToken: tempToken)
        } catch let networkError as NetworkError {
            switch networkError {
            case .clientError(429, _, let headers, _):
                // Handle rate limit with retry-after
                if let retryAfter = headers["Retry-After"].flatMap(Int.init) {
                    throw NetworkError.clientError(
                        statusCode: 429,
                        description: "Please wait \(retryAfter) seconds before requesting another code",
                        headers: headers
                    )
                }
                throw NetworkError.clientError(
                    statusCode: 429,
                    description: "Please wait before requesting another code",
                    headers: headers
                )
            default:
                throw networkError
            }
        }
    }
}
