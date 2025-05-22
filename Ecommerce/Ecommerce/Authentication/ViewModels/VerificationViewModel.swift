import SwiftUI
import Networking

@Observable
@MainActor
class VerificationViewModel {
    // MARK: - Dependencies
    private let authManager: AuthManager
    private let emailVerificationManager: EmailVerificationManager
    
    // MARK: - Properties
    let type: VerificationType
    var verificationCode = ""
    var error: Error?
    var isLoading = false
    var showError = false
    var errorMessage = ""
    var showSuccess = false
    var successMessage = ""
    var isResendingCode = false
    var resendCooldown = 0
    var expirationTimer = 300 // 5 minutes
    var isExpirationTimerRunning = false
    var showingSkipAlert = false
    var attemptsRemaining = 3
    var showMFAEnabledAlert = false
    var isInitialSend = true
    var showRecoveryCodesSheet = false
    var shouldSignOutAfterDismiss = false
    
    // MARK: - Initialization
    init(type: VerificationType, authManager: AuthManager, emailVerificationManager: EmailVerificationManager) {
        self.type = type
        self.authManager = authManager
        self.emailVerificationManager = emailVerificationManager
    }
    
    // MARK: - Public Methods
    func verify() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            switch type {
            case .initialEmail(let stateToken, let email):
                let response = try await emailVerificationManager.verifyInitialEmail(code: verificationCode, stateToken: stateToken, email: email)
                await authManager.completeSignIn(response: response)
                return true
            case .initialEmailFromAccountSettings(let email):
                _ = try await emailVerificationManager.verifyInitialEmail(code: verificationCode, stateToken: "", email: email)
                await authManager.refreshProfile()
                return true
            case .enableEmailMFA(let email):
                let codes = try await emailVerificationManager.verifyEmailMFA(code: verificationCode, email: email)
                authManager.recoveryCodesManager.codes = codes
                shouldSignOutAfterDismiss = true
                if !codes.isEmpty {
                    showMFAEnabledAlert = true
                } else {
                    showSuccess = true
                    successMessage = "Email MFA has been enabled successfully."
                    authManager.isAuthenticated = false
                }
                return true
            case .enableTOTP:
                let codes = try await authManager.totpManager.verifyTOTP(code: verificationCode)
                authManager.recoveryCodesManager.codes = codes
                shouldSignOutAfterDismiss = true
                if !codes.isEmpty {
                    showMFAEnabledAlert = true
                } else {
                    showSuccess = true
                    successMessage = "Authenticator app has been enabled successfully."
                    authManager.isAuthenticated = false
                }
                return true
            default:
                try await authManager.completeMFAVerification(for: type, code: verificationCode)
                return true
            }
        } catch let error as NetworkError {
            handleNetworkError(error)
        } catch {
            handleUnexpectedError()
        }
        return false
    }
    
    func sendCode() async {
        isResendingCode = true
        defer { isResendingCode = false }
        
        do {
            if !isInitialSend {
                switch type {
                case .initialEmail(let stateToken, let email):
                    try await authManager.resendInitialEmailVerificationCode(stateToken: stateToken, email: email)
                case .initialEmailFromAccountSettings(let email):
                    try await authManager.resendInitialEmailVerificationCode(stateToken: "", email: email)
                case .emailSignIn:
                    try await authManager.resendEmailMFASignIn(stateToken: type.stateToken)
                case .enableEmailMFA:
                    try await emailVerificationManager.resendEmailMFACode()
                default:
                    try await sendVerificationCode()
                }
            } else {
                try await sendVerificationCode()
            }
            
            if type.isEmail {
                startTimers()
            }
            
            if !isInitialSend && type.isEmail {
                showError = false
                showSuccess = true
                successMessage = type.resendMessage
            }
        } catch let error as NetworkError {
            handleNetworkError(error)
        } catch {
            handleUnexpectedError()
        }
    }
    
    // MARK: - Public Helper Methods
    public func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    public func formatRecoveryCode(_ code: String) -> String {
        let cleaned = code.filter { $0.isNumber || $0.isLetter }
        var result = ""
        var index = 0
        
        for char in cleaned {
            if index > 0 && index % 4 == 0 && index < 16 {
                result += "-"
            }
            result.append(char)
            index += 1
        }
        
        return String(result.prefix(19)) // 16 chars + 3 hyphens
    }
    
    // MARK: - Additional Public Methods for View
    public func handleInitialCodeSending() async {
        guard resendCooldown == 0 else {
            showError = true
            errorMessage = "Please wait \(formatTime(resendCooldown)) before requesting another code."
            return
        }
        switch type {
        case .emailSignIn(let stateToken):
            if !stateToken.isEmpty {
                await sendCode()
            }
        case .initialEmail(let stateToken, _):
            if !stateToken.isEmpty, !authManager.isAuthenticated {
                await sendCode()
            }
        case .initialEmailFromAccountSettings, .enableEmailMFA:
            if authManager.isAuthenticated {
                await sendCode()
            }
        default:
            break
        }
    }

    public var isValidRecoveryCode: Bool {
        let cleaned = verificationCode.filter { $0.isNumber || $0.isLetter }
        return cleaned.count == 16
    }
    
    // MARK: - Private Methods
    private func startExpirationTimer() {
        expirationTimer = 300
        isExpirationTimerRunning = true
        
        Task {
            while expirationTimer > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                expirationTimer -= 1
            }
            isExpirationTimerRunning = false
        }
    }
    
    private func startResendCooldown() {
        Task {
            while resendCooldown > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
    
    private func startTimers() {
        startExpirationTimer()
        resendCooldown = 120
        startResendCooldown()
        
        if type.isEmail {
            attemptsRemaining = 3
        }
    }
    
    private func sendVerificationCode() async throws {
        switch type {
        case .initialEmail(let stateToken, let email):
            try await emailVerificationManager.sendInitialVerificationEmail(stateToken: stateToken, email: email)
        case .initialEmailFromAccountSettings(let email):
            try await emailVerificationManager.sendInitialVerificationEmail(stateToken: "", email: email)
        case .emailSignIn(let stateToken):
            try await authManager.sendEmailMFASignIn(stateToken: stateToken)
        case .enableEmailMFA:
            try await emailVerificationManager.enableEmailMFA()
        default:
            break
        }
    }
    
    private func handleNetworkError(_ error: NetworkError) {
        showError = true
        if case .clientError(let statusCode, _, let headers, _) = error, statusCode == 429 {
            handleRateLimitError(headers)
        } else {
            errorMessage = "Failed to send verification code. Please try again."
        }
    }
    
    private func handleRateLimitError(_ headers: [String: String]) {
        if let retryAfterStr = headers["Retry-After"], let retryAfter = Int(retryAfterStr) {
            resendCooldown = retryAfter
            errorMessage = "Please wait \(formatTime(retryAfter)) before requesting another code."
        } else {
            resendCooldown = 120
            errorMessage = "Too many requests. Please wait before trying again."
        }
        startResendCooldown()
    }
    
    private func handleUnexpectedError() {
        showError = true
        errorMessage = "An unexpected error occurred. Please try again."
    }
} 
