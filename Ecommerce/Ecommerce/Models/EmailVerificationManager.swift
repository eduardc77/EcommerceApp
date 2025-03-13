import Observation
import Networking

@Observable
public final class EmailVerificationManager {
    private let emailVerificationService: EmailVerificationServiceProtocol
    
    public var isLoading = false
    public var error: Error?
    public var isVerified = false
    
    public init(emailVerificationService: EmailVerificationServiceProtocol) {
        self.emailVerificationService = emailVerificationService
    }
    
    @MainActor
    public func sendVerificationCode() async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.sendCode()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func verifyEmailCode(_ code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.verify(code: code)
            isVerified = true
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func getEmailVerificationStatus() async {
        isLoading = true
        error = nil
        do {
            isVerified = try await emailVerificationService.getStatus().verified
        } catch {
            self.error = error
        }
        isLoading = false
    }
} 
