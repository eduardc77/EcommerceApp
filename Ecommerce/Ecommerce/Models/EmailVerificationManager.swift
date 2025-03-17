import Observation
import Networking

/// Manages the email verification process and state
@Observable
@MainActor  // Ensure all state mutations happen on main thread
public final class EmailVerificationManager {
    private let emailVerificationService: EmailVerificationServiceProtocol
    
    /// Indicates if a verification operation is in progress
    private(set) public var isLoading = false
    
    /// The last error that occurred during verification
    private(set) public var error: Error?
    
    /// Whether email verification is currently required
    public var requiresEmailVerification = false
    
    /// Specific verification-related error
    private(set) public var verificationError: VerificationError?
    
    public init(emailVerificationService: EmailVerificationServiceProtocol) {
        self.emailVerificationService = emailVerificationService
    }
    
    /// Resets all state variables to their default values
    public func reset() {
        requiresEmailVerification = false
        isLoading = false
        error = nil
        verificationError = nil
    }
    
    /// Skips the email verification requirement
    public func skipEmailVerification() {
        requiresEmailVerification = false
    }
    
    /// Fetches the initial verification status from the server
    public func getInitialStatus() async {
        isLoading = true
        error = nil
        verificationError = nil
        do {
            let status = try await emailVerificationService.getInitialStatus()
            requiresEmailVerification = !status.verified
        } catch {
            self.error = error
            if let verificationError = error as? VerificationError {
                self.verificationError = verificationError
            } else {
                self.verificationError = .unknown(error.localizedDescription)
            }
        }
        isLoading = false
    }
    
    /// Attempts to verify an email with a verification code
    /// - Parameters:
    ///   - email: The email address to verify
    ///   - code: The verification code
    /// - Returns: Whether verification was successful
    public func verifyEmail(email: String, code: String) async -> Bool {
        isLoading = true
        error = nil
        verificationError = nil
        defer { isLoading = false }

        do {
            _ = try await emailVerificationService.verifyInitialEmail(email: email, code: code)
            requiresEmailVerification = false
            return true
        } catch let networkError as NetworkError {
            error = networkError
            verificationError = {
                switch networkError {
                case .unauthorized:
                    return .invalidCode
                case .notFound:
                    return .emailNotFound
                case .forbidden:
                    return .tooManyAttempts
                case .clientError(let statusCode, let description, _):
                    switch statusCode {
                    case 400:
                        return .invalidCode
                    case 429:
                        return .tooManyAttempts
                    default:
                        return .unknown(description)
                    }
                default:
                    return .unknown(networkError.localizedDescription)
                }
            }()
            return false
        } catch {
            self.error = error
            verificationError = .unknown(error.localizedDescription)
            return false
        }
    }
    
    /// Requests a new verification code be sent
    /// - Parameter email: The email address to send the code to
    public func resendVerificationEmail(email: String) async {
        isLoading = true
        error = nil
        verificationError = nil
        
        do {
            _ = try await emailVerificationService.resendVerificationEmail(email: email)
        } catch {
            self.error = error
            if let verificationError = error as? VerificationError {
                self.verificationError = verificationError
            } else {
                self.verificationError = .unknown(error.localizedDescription)
            }
        }
        isLoading = false
    }
    
    /// Handles email updates by resetting verification state and sending a new code
    /// - Parameter email: The new email address to verify
    public func handleEmailUpdate(email: String) async {
        requiresEmailVerification = true
        isLoading = true
        error = nil
        verificationError = nil
        
        await resendVerificationEmail(email: email)
    }
} 
