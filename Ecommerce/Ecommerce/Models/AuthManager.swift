import Foundation
import Networking
import OSLog

enum AuthenticationError: Error {
    case noSignInInProgress
    case invalidTOTPToken
    case invalidCredentials
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case unknown
}

@Observable
@MainActor
public final class AuthManager: ObservableObject {
    private let authService: AuthenticationServiceProtocol
    private let userService: UserServiceProtocol
    private let authorizationManager: AuthorizationManagerProtocol
    public let totpManager: TOTPManager
    private let emailVerificationManager: EmailVerificationManager
    public let recoveryCodesManager: RecoveryCodesManager
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Ecommerce", category: "AuthenticationManager")

    public var currentUser: UserResponse?
    public var isAuthenticated = false
    public var isLoading = false
    public var error: Error?
    public var signInError: SignInError?
    public var signUpError: RegistrationError?
    public var requiresTOTPVerification = false
    public var requiresEmailMFAVerification = false
    public var requiresPasswordUpdate = false
    public var requiresEmailVerification: Bool = false
    public var pendingSignInResponse: AuthResponse?
    public var pendingCredentials: (identifier: String, password: String)?
    public var availableMFAMethods: [MFAMethod] = []

    public init(
        authService: AuthenticationServiceProtocol,
        userService: UserServiceProtocol,
        totpManager: TOTPManager,
        emailVerificationManager: EmailVerificationManager,
        recoveryCodesManager: RecoveryCodesManager,
        authorizationManager: AuthorizationManagerProtocol
    ) {
        self.authService = authService
        self.userService = userService
        self.totpManager = totpManager
        self.emailVerificationManager = emailVerificationManager
        self.recoveryCodesManager = recoveryCodesManager
        self.authorizationManager = authorizationManager

        // Check token validity on init
        Task {
            await validateSession()
        }
    }

    private func validateSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await authService.me()
            currentUser = response
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUser = nil
            try? await authorizationManager.invalidateToken()
        }
    }

    public func signUp(
        username: String,
        email: String,
        password: String,
        displayName: String
    ) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Store credentials before making the request - use email as identifier for future signin
            pendingCredentials = (identifier: email, password: password)
            
            let request = SignUpRequest(
                username: username,
                displayName: displayName,
                email: email,
                password: password
            )
            
            let response = try await authService.signUp(request: request)
            await completeSignIn(response: response)
        } catch {
            pendingCredentials = nil
            throw error
        }
    }

    public func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await authService.signOut()
        } catch {
            logger.error("Error during sign out: \(error)")
        }

        // Reset state regardless of sign out success
        isAuthenticated = false
        currentUser = nil
        pendingSignInResponse = nil
        pendingCredentials = nil
        requiresTOTPVerification = false
        requiresEmailMFAVerification = false
        requiresPasswordUpdate = false
        requiresEmailVerification = false
        availableMFAMethods = []
        try? await authorizationManager.invalidateToken()
    }

    private func handleSignInError(_ error: Error) async {
        if let networkError = error as? NetworkError {
            switch networkError {
            case let .clientError(statusCode, _, headers, data):
                switch statusCode {
                case 423:
                    signInError = .accountLocked(retryAfter: nil)
                case 429:
                    let retryAfter = headers["Retry-After"].flatMap(Int.init) ?? 900 // Default to 15 minutes
                    signInError = .accountLocked(retryAfter: retryAfter)
                case 401:
                    // Check if this is a TOTP required response
                    if let data = data,
                       let response = try? JSONDecoder().decode(AuthResponse.self, from: data),
                       response.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED {
                        // Handle TOTP requirement without setting error state
                        requiresTOTPVerification = true
                        pendingSignInResponse = response
                        return
                    }
                    signInError = .invalidCredentials
                default:
                    signInError = .unknown(networkError.localizedDescription)
                }
            default:
                signInError = .unknown(networkError.localizedDescription)
            }
        } else {
            signInError = .unknown(error.localizedDescription)
        }

        isAuthenticated = false
        currentUser = nil
        try? await authorizationManager.invalidateToken()
    }

    public func signIn(identifier: String, password: String) async {
        isLoading = true
        defer { isLoading = false }

        // Reset state
        signInError = nil
        isAuthenticated = false
        pendingSignInResponse = nil
        requiresTOTPVerification = false
        requiresEmailMFAVerification = false
        availableMFAMethods = []

        do {
            let dto = SignInRequest(identifier: identifier, password: password)
            let response = try await authService.signIn(request: dto)
            
            self.pendingCredentials = (identifier: identifier, password: password)
            
            // Handle response based on status
            await completeSignIn(response: response)
        } catch {
            await handleSignInError(error)
        }
    }

    public func signInWithGoogle(idToken: String, accessToken: String? = nil) async throws -> AuthResponse {
        isLoading = true
        defer { isLoading = false }

        // Reset state
        signInError = nil
        isAuthenticated = false
        pendingSignInResponse = nil
        requiresTOTPVerification = false
        requiresEmailMFAVerification = false
        availableMFAMethods = []

        let response = try await authService.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        
        // For social sign-ins, we don't need additional MFA verification
        // The provider (Google) already handles their own 2FA/security
        isAuthenticated = true
        currentUser = response.user
        
        // Store tokens
        if let accessToken = response.accessToken,
           let refreshToken = response.refreshToken,
           let expiresIn = response.expiresIn,
           let expiresAt = response.expiresAt {
            let token = Token(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: response.tokenType,
                expiresIn: expiresIn,
                expiresAt: expiresAt
            )
            await authorizationManager.storeToken(token)
        }
        
        return response
    }

    public func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]? = nil,
        email: String? = nil
    ) async throws -> AuthResponse {
        isLoading = true
        defer { isLoading = false }

        // Reset state
        signInError = nil
        isAuthenticated = false
        pendingSignInResponse = nil
        requiresTOTPVerification = false
        requiresEmailMFAVerification = false
        availableMFAMethods = []

        let response = try await authService.signInWithApple(
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            fullName: fullName,
            email: email
        )
        
        // For social sign-ins, we don't need additional MFA verification
        // The provider (Apple) already handles their own 2FA/security
        isAuthenticated = true
        currentUser = response.user
        
        // Store tokens
        if let accessToken = response.accessToken,
           let refreshToken = response.refreshToken,
           let expiresIn = response.expiresIn,
           let expiresAt = response.expiresAt {
            let token = Token(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: response.tokenType,
                expiresIn: expiresIn,
                expiresAt: expiresAt
            )
            await authorizationManager.storeToken(token)
        }
        
        return response
    }

    public func completeSignIn(response: AuthResponse) async {
        // Store tokens if available and not in a verification state
        if let accessToken = response.accessToken,
           let refreshToken = response.refreshToken,
           let expiresIn = response.expiresIn,
           let expiresAt = response.expiresAt {
            let token = Token(
                accessToken: accessToken,
                refreshToken: refreshToken,
                tokenType: response.tokenType,
                expiresIn: expiresIn,
                expiresAt: expiresAt
            )
            await authorizationManager.storeToken(token)
        }
        
        // Update user info if available
        if let user = response.user {
            currentUser = user
        }
        
        // Handle different auth states
        switch response.status {
        case AuthResponse.STATUS_SUCCESS:
            isAuthenticated = true
            pendingSignInResponse = nil
            requiresTOTPVerification = false
            requiresEmailMFAVerification = false
            requiresEmailVerification = false
            requiresPasswordUpdate = false
            emailVerificationManager.requiresEmailVerification = false
            availableMFAMethods = []
            
        case AuthResponse.STATUS_MFA_REQUIRED:
            isAuthenticated = false
            pendingSignInResponse = response
            availableMFAMethods = response.availableMfaMethods ?? []
            requiresTOTPVerification = false
            requiresEmailMFAVerification = false
            
        case AuthResponse.STATUS_MFA_TOTP_REQUIRED:
            isAuthenticated = false
            requiresTOTPVerification = true
            requiresEmailMFAVerification = false
            pendingSignInResponse = response
            availableMFAMethods = [.totp]
            
        case AuthResponse.STATUS_MFA_EMAIL_REQUIRED:
            isAuthenticated = false
            requiresTOTPVerification = false
            requiresEmailMFAVerification = true
            pendingSignInResponse = response
            availableMFAMethods = [.email]
            
        case AuthResponse.STATUS_VERIFICATION_REQUIRED,
             AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED:
            isAuthenticated = false
            requiresEmailVerification = true
            emailVerificationManager.requiresEmailVerification = true
            pendingSignInResponse = response
            // Keep credentials for auto-signin after verification
            if let identifier = pendingCredentials?.identifier,
               let password = pendingCredentials?.password {
                pendingCredentials = (identifier: identifier, password: password)
            }
        case AuthResponse.STATUS_PASSWORD_RESET_REQUIRED,
             AuthResponse.STATUS_PASSWORD_UPDATE_REQUIRED:
            isAuthenticated = false
            requiresPasswordUpdate = true
            pendingSignInResponse = response
            
        default:
            logger.error("Unknown auth status: \(response.status)")
            isAuthenticated = false
            pendingSignInResponse = nil
            requiresTOTPVerification = false
            requiresEmailMFAVerification = false
            requiresEmailVerification = false
            requiresPasswordUpdate = false
            availableMFAMethods = []
        }
    }

    public func selectMFAMethod(method: MFAMethod, stateToken: String? = nil) async throws {
        let token = stateToken ?? pendingSignInResponse?.stateToken
        guard let token = token else {
            throw AuthenticationError.noSignInInProgress
        }

        do {
            let response = try await authService.selectMFAMethod(method: method.rawValue, stateToken: token)
            await completeSignIn(response: response)
        } catch {
            pendingSignInResponse = nil
            throw error
        }
    }

    public func verifyTOTPSignIn(code: String, stateToken: String) async throws {
        guard pendingSignInResponse != nil else {
            throw AuthenticationError.noSignInInProgress
        }

        do {
            let response = try await authService.verifyTOTPSignIn(code: code, stateToken: stateToken)
            await completeSignIn(response: response)
        } catch {
            pendingSignInResponse = nil
            throw error
        }
    }

    public func verifyEmailMFASignIn(code: String, stateToken: String) async throws {
        guard pendingSignInResponse != nil else {
            throw AuthenticationError.noSignInInProgress
        }

        do {
            let response = try await authService.verifyEmailMFASignIn(code: code, stateToken: stateToken)
            await completeSignIn(response: response)
            self.pendingSignInResponse = nil
        } catch {
            self.pendingSignInResponse = nil
            throw error
        }
    }

    public func resendEmailMFASignIn(stateToken: String) async throws {
        guard pendingSignInResponse != nil else {
            throw AuthenticationError.noSignInInProgress
        }

        do {
            _ = try await authService.resendEmailMFASignIn(stateToken: stateToken)
        } catch {
            throw error
        }
    }

    /// Request a new email verification code during sign-in
    public func requestEmailCode(stateToken: String) async throws {
        guard pendingSignInResponse != nil else {
            throw AuthenticationError.noSignInInProgress
        }
        _ = try await authService.requestEmailCode(stateToken: stateToken)
    }

    /// Send email MFA verification code during sign-in
    public func sendEmailMFASignIn(stateToken: String) async throws {
        guard pendingSignInResponse != nil else {
            throw AuthenticationError.noSignInInProgress
        }
        _ = try await authService.sendEmailMFASignIn(stateToken: stateToken)
    }

    /// Send initial MFA code based on the verification type
    public func sendInitialMFACode(for type: VerificationType) async throws {
        switch type {
        case .emailSignIn(let stateToken):
            _ = try await authService.sendEmailMFASignIn(stateToken: stateToken)
        default:
            break // These are handled by their respective managers
        }
    }

    /// Complete MFA verification based on the verification type
    public func completeMFAVerification(for type: VerificationType, code: String) async throws {
        switch type {
        case .emailSignIn(let stateToken):
            try await verifyEmailMFASignIn(code: code, stateToken: stateToken)
        case .totpSignIn(let stateToken):
            try await verifyTOTPSignIn(code: code, stateToken: stateToken)
        case .recoveryCodeSignIn(let stateToken):
            try await verifyRecoveryCode(code: code, stateToken: stateToken)
        default:
            break // These are handled by their respective managers
        }
    }

    public func verifyRecoveryCode(code: String, stateToken: String) async throws {
        guard pendingSignInResponse != nil else {
            throw AuthenticationError.noSignInInProgress
        }

        do {
            let response = try await authService.verifyRecoveryCode(code: code, stateToken: stateToken)
            await completeSignIn(response: response)
            self.pendingSignInResponse = nil
        } catch {
            self.pendingSignInResponse = nil
            throw error
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
                let signInDTO = SignInRequest(identifier: newEmail, password: "") // Password not needed as we're already authenticated
                let response = try await authService.signIn(request: signInDTO)
                currentUser = response.user
                return newEmail // Return the new email if it was updated
            }
            return nil
        } catch {
            self.error = error
            return nil
        }
    }

    /// Refreshes the user's profile information
    public func refreshProfile() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        
        do {
            let response = try await authService.me()
            currentUser = response
            // Refresh all MFA statuses
            try await emailVerificationManager.getEmailMFAStatus()
            try await totpManager.getMFAStatus()
            try await recoveryCodesManager.getStatus()
        } catch {
            logger.error("Error refreshing profile: \(error)")
            // Don't sign out on profile refresh failure
        }
    }

    public func resendInitialEmailVerificationCode(stateToken: String, email: String) async throws {
        _ = try await authService.resendInitialEmailVerificationCode(stateToken: stateToken, email: email)
    }

    /// Refresh available MFA methods
    public func refreshMFAMethods() async throws {
        let response = try await authService.getMFAMethods(stateToken: nil)
        availableMFAMethods = response.methods
    }

    /// Disables TOTP MFA for the current user
    /// - Parameter password: The user's password for verification
    public func disableTOTP(password: String) async throws {
        try await totpManager.disable(password: password)
    }

    /// Disables email MFA for the current user
    /// - Parameter password: The user's password for verification
    public func disableEmailMFA(password: String) async throws {
        try await emailVerificationManager.disableEmailMFA(password: password)
    }

    public func requestPasswordReset(email: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await authService.forgotPassword(email: email)
        } catch {
            throw error
        }
    }
    
    public func resetPassword(email: String, code: String, newPassword: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let request = ResetPasswordRequest(
                email: email,
                code: code,
                newPassword: newPassword
            )
            let _ = try await authService.resetPassword(request: request)
            // No need to complete sign in here since we want user to sign in with new password
        } catch {
            throw error
        }
    }
    
    public func changePassword(currentPassword: String, newPassword: String) async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let request = ChangePasswordRequest(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            try await authService.changePassword(request: request)
        } catch {
            throw error
        }
    }
}


