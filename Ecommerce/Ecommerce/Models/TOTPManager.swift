import Observation
import Networking

@Observable
public final class TOTPManager {
    private let totpService: TOTPServiceProtocol
    
    public var isLoading = false
    public var error: Error?
    public var isEnabled = false
    
    public init(totpService: TOTPServiceProtocol) {
        self.totpService = totpService
    }
    
    @MainActor
    public func setupTOTP() async -> String? {
        isLoading = true
        error = nil
        do {
            let response = try await totpService.setup()
            isLoading = false
            return response.qrCodeUrl
        } catch {
            self.error = error
            isLoading = false
            return nil
        }
    }
    
    @MainActor
    public func verifyTOTP(_ code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.verify(code: code)
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func getTOTPStatus() async {
        isLoading = true
        error = nil
        do {
            let status = try await totpService.getStatus()
            isEnabled = status.enabled
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func enableTOTP(_ code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.enable(code: code)
            isEnabled = true
        } catch {
            self.error = error
        }
        isLoading = false
    }
    
    @MainActor
    public func disableTOTP(_ code: String) async {
        isLoading = true
        error = nil
        do {
            _ = try await totpService.disable(code: code)
            isEnabled = false
        } catch {
            self.error = error
        }
        isLoading = false
    }
} 