import Observation
import Networking

@Observable
public final class EmailVerificationManager {
    private let emailVerificationService: EmailVerificationServiceProtocol
    
    public var isLoading = false
    public var error: Error?
    public var isVerified = false
    public var is2FAEnabled = false
    
    public init(emailVerificationService: EmailVerificationServiceProtocol) {
        self.emailVerificationService = emailVerificationService
    }
    
    @MainActor
    public func getInitialStatus() async {
        isLoading = true
        error = nil
        do {
            let status = try await emailVerificationService.getInitialStatus()
            isVerified = status.verified
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func get2FAStatus() async {
        isLoading = true
        error = nil
        do {
            let status = try await emailVerificationService.get2FAStatus()
            is2FAEnabled = status.enabled
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func verifyInitialEmail(email: String, code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.verifyInitialEmail(email: email, code: code)
            isVerified = true
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func resendVerificationEmail(email: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.resendVerificationEmail(email: email)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func setup2FA() async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.setup2FA()
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func verify2FA(code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.verify2FA(code: code)
            is2FAEnabled = true
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func disable2FA() async {
        isLoading = true
        error = nil
        do {
            _ = try await emailVerificationService.disable2FA()
            is2FAEnabled = false
        } catch {
            self.error = error
        }
        isLoading = false
    }
} 
