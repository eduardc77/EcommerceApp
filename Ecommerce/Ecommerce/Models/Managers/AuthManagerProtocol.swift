import Foundation
import Networking

@MainActor
protocol AuthManagerProtocol: Sendable {
    // MARK: - Properties
    var currentUser: UserResponse? { get }
    var isAuthenticated: Bool { get }
    var isLoading: Bool { get }
    var error: Error? { get }
    var signInError: SignInError? { get }
    var signUpError: RegistrationError? { get }
    var requiresTOTPVerification: Bool { get }
    var requiresEmailMFAVerification: Bool { get }
    var requiresPasswordUpdate: Bool { get }
    var requiresEmailVerification: Bool { get }
    var pendingSignInResponse: AuthResponse? { get }
    var pendingCredentials: (identifier: String, password: String)? { get }
    var availableMFAMethods: [MFAMethod] { get }

    // MARK: - Authentication Methods
    func signInWithGoogle(idToken: String, accessToken: String?) async throws -> AuthResponse
    func signInWithApple(identityToken: String, authorizationCode: String, fullName: [String: String?]?, email: String?) async throws -> AuthResponse
    func signIn(identifier: String, password: String) async
    func signUp(username: String, email: String, password: String, displayName: String) async throws
    func signOut() async
    
    // MARK: - MFA Methods
    func selectMFAMethod(method: MFAMethod, stateToken: String?) async throws
    func verifyTOTPSignIn(code: String, stateToken: String) async throws
    func verifyEmailMFASignIn(code: String, stateToken: String) async throws
    func verifyRecoveryCode(code: String, stateToken: String) async throws
    func resendEmailMFASignIn(stateToken: String) async throws
    func requestEmailCode(stateToken: String) async throws
    func sendEmailMFASignIn(stateToken: String) async throws
    func sendInitialMFACode(for type: VerificationType) async throws
    func completeMFAVerification(for type: VerificationType, code: String) async throws
    func refreshMFAMethods() async throws
    func disableTOTP(password: String) async throws
    func disableEmailMFA(password: String) async throws
    
    // MARK: - Profile Management
    func updateProfile(displayName: String, email: String?, profilePicture: String?) async -> String?
    func refreshProfile() async
    
    // MARK: - Email Verification
    func resendInitialEmailVerificationCode(stateToken: String, email: String) async throws
    
    // MARK: - Password Management
    func requestPasswordReset(email: String) async throws
    func resetPassword(email: String, code: String, newPassword: String) async throws
    func changePassword(currentPassword: String, newPassword: String) async throws
    func validateEmail(_ email: String) -> (isValid: Bool, error: String?)
    func sendPasswordResetInstructions(email: String) async throws
    
    // MARK: - Sign In Completion
    func completeSignIn(response: AuthResponse) async
} 
