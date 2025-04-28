import Foundation

/// Protocol for authentication service
public protocol AuthenticationServiceProtocol: Actor {
    
    /// Sign in with username/email and password
    /// - Parameter request: Sign in request with credentials
    @Sendable func signIn(request: SignInRequest) async throws -> AuthResponse
    
    /// Complete multi-factor authentication with TOTP code
    /// - Parameters:
    ///   - code: The TOTP code
    ///   - stateToken: State token received from initial sign-in
    @Sendable func verifyTOTPSignIn(code: String, stateToken: String) async throws -> AuthResponse
    
    /// Complete multi-factor authentication with email code
    /// - Parameters:
    ///   - code: The email verification code
    ///   - stateToken: State token received from initial sign-in
    @Sendable func verifyEmailMFASignIn(code: String, stateToken: String) async throws -> AuthResponse
    
    /// Complete multi-factor authentication with recovery code
    /// - Parameters:
    ///   - code: The recovery code
    ///   - stateToken: State token received from initial sign-in
    @Sendable func verifyRecoveryCode(code: String, stateToken: String) async throws -> AuthResponse
    
    /// Select MFA method to use during sign-in
    /// - Parameters:
    ///   - method: The MFA method to use ("totp" or "email")
    ///   - stateToken: State token received from initial sign-in
    @Sendable func selectMFAMethod(method: String, stateToken: String) async throws -> AuthResponse
    
    /// Get available MFA methods for the user
    /// - Parameter stateToken: Optional state token from initial sign-in
    @Sendable func getMFAMethods(stateToken: String?) async throws -> MFAMethodsResponse
    
    /// Request a new email verification code during sign-in
    /// - Parameter stateToken: State token received from initial sign-in
    @Sendable func requestEmailCode(stateToken: String) async throws -> MessageResponse
    
    /// Send initial email MFA verification code during sign-in
    /// - Parameter stateToken: State token received from initial sign-in
    @Sendable func sendEmailMFASignIn(stateToken: String) async throws -> MessageResponse
    
    /// Resend email MFA verification code during sign-in
    /// - Parameter stateToken: State token received from initial sign-in
    @Sendable func resendEmailMFASignIn(stateToken: String) async throws -> MessageResponse
    
    /// Sign up a new user account
    /// - Parameter request: Registration request with user details
    @Sendable func signUp(request: SignUpRequest) async throws -> AuthResponse
    
    /// Sign out the current user
    @Sendable func signOut() async throws
    
    /// Get the current user's profile
    @Sendable func me() async throws -> UserResponse
    
    /// Get user info according to OpenID Connect standard
    @Sendable func getUserInfo() async throws -> UserInfoResponse
    
    /// Change the current user's password
    /// - Parameter request: Change password request
    @Sendable func changePassword(request: ChangePasswordRequest) async throws
    
    /// Request a password reset
    /// - Parameter email: User's email address
    @Sendable func forgotPassword(email: String) async throws -> MessageResponse
    
    /// Reset password with code
    /// - Parameters:
    ///   - email: User's email address
    ///   - code: Password reset code
    ///   - newPassword: New password
    @Sendable func resetPassword(request: ResetPasswordRequest) async throws -> MessageResponse
    
    /// Get all active sessions for the current user
    @Sendable func listSessions() async throws -> SessionListResponse
    
    /// Revoke a specific session
    /// - Parameter sessionId: The session ID to revoke
    @Sendable func revokeSession(sessionId: String) async throws -> MessageResponse
    
    /// Revoke all sessions except the current one
    @Sendable func revokeAllOtherSessions() async throws -> MessageResponse
    
    /// Cancel an in-progress authentication flow
    @Sendable func cancelAuthentication() async throws -> MessageResponse
    
    /// Revoke a specific access token
    /// - Parameter token: The token to revoke
    @Sendable func revokeAccessToken(_ token: String) async throws -> MessageResponse
    
    /// Refresh the current access token
    @Sendable func refreshToken(_ refreshToken: String) async throws -> AuthResponse

    /// Sign in with Google OAuth credentials
    /// - Parameters:
    ///   - idToken: The ID token received from Google Sign-In
    ///   - accessToken: The access token received from Google Sign-In (optional)
    @Sendable func signInWithGoogle(idToken: String, accessToken: String?) async throws -> AuthResponse
    
    /// Handle Google OAuth callback
    /// - Parameter code: The authorization code from Google
    @Sendable func handleGoogleCallback(code: String) async throws -> AuthResponse
    
    /// Sign in with Apple Sign In credentials
    /// - Parameters:
    ///   - identityToken: The identity token string from Sign in with Apple
    ///   - authorizationCode: The authorization code from Sign in with Apple
    ///   - fullName: User's name components (optional, only provided on first sign-in)
    ///   - email: User's email (optional, only provided on first sign-in)
    @Sendable func signInWithApple(
        identityToken: String,
        authorizationCode: String,
        fullName: [String: String?]?,
        email: String?
    ) async throws -> AuthResponse
    
    /// Handle Apple Sign In callback
    /// - Parameter code: The authorization code from Apple
    @Sendable func handleAppleCallback(code: String) async throws -> AuthResponse
    
    /// Exchange authorization code for tokens
    /// - Parameters:
    ///   - code: The authorization code
    ///   - codeVerifier: The PKCE code verifier that corresponds to the code challenge sent in the authorization request
    ///   - redirectUri: The redirect URI
    @Sendable func exchangeCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectUri: String
    ) async throws -> AuthResponse
    
    /// Resend initial email verification code during sign-up
    /// - Parameters:
    ///   - stateToken: State token received from sign-up
    ///   - email: User's email address
    @Sendable func resendInitialEmailVerificationCode(stateToken: String, email: String) async throws -> MessageResponse
    
    /// Initiate social sign in by getting the authorization URL
    /// - Parameters:
    ///   - provider: The social provider (e.g., "google", "apple")
    ///   - redirectUri: The URI to redirect to after authorization
    ///   - codeChallenge: The PKCE code challenge
    ///   - codeChallengeMethod: The PKCE code challenge method (e.g., "S256")
    ///   - state: A random string to prevent CSRF attacks
    ///   - scope: Optional space-separated list of scopes
    /// - Returns: The authorization URL to redirect the user to
    @Sendable func initiateSocialSignIn(
        provider: String,
        redirectUri: String,
        codeChallenge: String,
        codeChallengeMethod: String,
        state: String,
        scope: String?
    ) async throws -> URL
} 
