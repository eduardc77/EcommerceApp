import Foundation

/// Protocol for authentication service
public protocol AuthenticationServiceProtocol {
    
    /// Login with username/email and password
    /// - Parameter request: Login request with credentials
    func login(request: LoginRequest) async throws -> AuthResponse
    
    /// Complete two-factor authentication with TOTP code
    /// - Parameters:
    ///   - code: The TOTP code
    ///   - tempToken: Temporary token received from initial login
    func verifyTOTPLogin(code: String, tempToken: String) async throws -> AuthResponse
    
    /// Complete two-factor authentication with email code
    /// - Parameters:
    ///   - code: The email verification code
    ///   - tempToken: Temporary token received from initial login
    func verifyEmail2FALogin(code: String, tempToken: String) async throws -> AuthResponse
    
    /// Register a new user account
    /// - Parameter request: Registration request with user details
    func register(request: CreateUserRequest) async throws -> AuthResponse
    
    /// Log out the current user
    func logout() async throws
    
    /// Get the current user's profile
    func me() async throws -> UserResponse
    
    /// Change the current user's password
    /// - Parameters:
    ///   - currentPassword: Current password
    ///   - newPassword: New password
    func changePassword(currentPassword: String, newPassword: String) async throws -> EmptyResponse
    
    /// Request a password reset
    /// - Parameter email: User's email address
    func forgotPassword(email: String) async throws -> EmptyResponse
    
    /// Reset password with code
    /// - Parameters:
    ///   - email: User's email address
    ///   - code: Password reset code
    ///   - newPassword: New password
    func resetPassword(email: String, code: String, newPassword: String) async throws -> EmptyResponse
    
    /// Login with Google OAuth credentials
    /// - Parameters:
    ///   - idToken: The ID token received from Google Sign-In
    ///   - accessToken: The access token received from Google Sign-In (optional)
    func loginWithGoogle(idToken: String, accessToken: String?) async throws -> AuthResponse
    
    /// Login with Apple Sign In credentials
    /// - Parameters:
    ///   - identityToken: The identity token string from Sign in with Apple
    ///   - authorizationCode: The authorization code from Sign in with Apple
    ///   - fullName: User's name components (optional, only provided on first login)
    ///   - email: User's email (optional, only provided on first login)
    func loginWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]?,
        email: String?
    ) async throws -> AuthResponse
} 