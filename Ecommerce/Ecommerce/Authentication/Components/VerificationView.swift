import SwiftUI

struct VerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(\.dismiss) private var dismiss

    let type: VerificationType
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isResendingCode = false
    @State private var resendCooldown = 0
    @State private var expirationTimer = 300 // 5 minutes
    @State private var isExpirationTimerRunning = false
    @State private var showingSkipAlert = false
    @State private var attemptsRemaining = 3 // Track remaining attempts (client-side limit)
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                codeInputSection
                actionButtonsSection
            }
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .onAppear {
                // Initialize view state
                isCodeFieldFocused = true
                showError = false
                errorMessage = ""
                verificationCode = ""
                
                // Send initial code if needed
                if type.showsResendButton {
                    if case .emailLogin = type {
                        // For email login, just start the timers since server already sent the code
                        startExpirationTimer()
                        resendCooldown = 120 // Start with full cooldown
                        startResendCooldown()
                        return
                    }
                    Task {
                        // Add a small delay to ensure view is fully loaded
                        try? await Task.sleep(for: .seconds(0.5))
                        await sendCode()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: type.icon.name)
                    .font(.system(size: 60))
                    .foregroundStyle(type.icon.color)

                VStack(spacing: 10) {
                    Text(type.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    type.descriptionText(email: authManager.currentUser?.email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        } footer: {
            if isExpirationTimerRunning {
                Text("Code expires in \(formatTime(expirationTimer))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var codeInputSection: some View {
        Section {
            OneTimeCodeInput(code: $verificationCode, codeLength: 6)
                .focused($isCodeFieldFocused)
                .frame(maxWidth: .infinity)
        } footer: {
            VStack {
                if showError {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.red)
                }
                if attemptsRemaining < 3 && type.isEmailVerification {
                    Text("\(attemptsRemaining) attempts remaining")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var actionButtonsSection: some View {
        Section {
            VStack(spacing: 10) {
                if type.showsResendButton {
                    resendButton
                }

                AsyncButton {
                    await verify()
                } label: {
                    Text(type.buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(verificationCode.count != 6 || isLoading || (type.isEmailVerification && attemptsRemaining == 0))

                if type.showsSkipButton {
                    Button {
                        showingSkipAlert = true
                    } label: {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var resendButton: some View {
        Group {
            if resendCooldown > 0 {
                Text("Resend available in \(formatTime(resendCooldown))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                AsyncButton("Resend Code", font: .footnote) {
                    await sendCode()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(isResendingCode)
            }
        }
    }

    private func startExpirationTimer() {
        expirationTimer = 300 // 5 minutes
        isExpirationTimerRunning = true

        Task {
            while expirationTimer > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                expirationTimer -= 1
            }
            isExpirationTimerRunning = false
        }
    }

    private func verify() async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch type {
            case .totpLogin(let tempToken):
                try await authManager.verifyTOTPForLogin(code: verificationCode, tempToken: tempToken)
                if !authManager.requires2FAEmailVerification {
                    dismiss()
                }

            case .emailLogin(let tempToken):
                try await authManager.verifyEmail2FALogin(code: verificationCode, tempToken: tempToken)
                authManager.isAuthenticated = true
                dismiss()

            case .initialEmail:
                try await emailVerificationManager.verifyInitialEmail(
                    email: authManager.currentUser?.email ?? "",
                    code: verificationCode
                )
                authManager.isAuthenticated = true
                dismiss()

            case .setupEmail2FA:
                try await emailVerificationManager.verify2FA(code: verificationCode)
                await authManager.signOut()
                dismiss()

            case .disableEmail2FA:
                try await emailVerificationManager.disable2FA(code: verificationCode)
                dismiss()
                await authManager.signOut()

            case .setupTOTP:
                try await authManager.totpManager.verifyAndEnableTOTP(code: verificationCode)
                await authManager.signOut()
                dismiss()

            case .disableTOTP:
                try await authManager.totpManager.disableTOTP(code: verificationCode)
                dismiss()
                await authManager.signOut()
            }
        } catch let networkError as NetworkError {
            showError = true
            if case .badRequest(let description) = networkError, description.contains("No verification code found") {
                // Reset verification state and request new code
                verificationCode = ""
                if type.isEmailVerification {
                    attemptsRemaining = 3 // Reset attempts for email verification
                }
                errorMessage = "Too many failed attempts. A new code has been requested."
                Task {
                    await sendCode() // Request a new verification code
                }
            } else {
                if type.isEmailVerification {
                    attemptsRemaining -= 1 // Decrement attempts only for email verification
                }
                switch type {
                case .totpLogin:
                    errorMessage = "Invalid authenticator code. Please try again."
                case .emailLogin, .initialEmail, .setupEmail2FA, .disableEmail2FA:
                    errorMessage = "Invalid verification code. Please check your email and try again."
                case .setupTOTP:
                    errorMessage = "Invalid authenticator code. Please make sure you entered the correct code from your authenticator app."
                case .disableTOTP:
                    errorMessage = "Invalid authenticator code. Please try again."
                }
            }
        } catch {
            showError = true
            if type.isEmailVerification {
                attemptsRemaining -= 1 // Decrement attempts only for email verification
            }
            switch type {
            case .totpLogin:
                errorMessage = "Invalid authenticator code. Please try again."
            case .emailLogin, .initialEmail, .setupEmail2FA, .disableEmail2FA:
                errorMessage = "Invalid verification code. Please check your email and try again."
            case .setupTOTP:
                errorMessage = "Invalid authenticator code. Please make sure you entered the correct code from your authenticator app."
            case .disableTOTP:
                errorMessage = "Invalid authenticator code. Please try again."
            }
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

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func sendCode() async {
        isResendingCode = true
        defer { isResendingCode = false }
        
        do {
            switch type {
            case .emailLogin(let tempToken):
                try await authManager.requestEmailCode(tempToken: tempToken)
            case .initialEmail:
                try await emailVerificationManager.resendVerificationEmail(email: authManager.currentUser?.email ?? "")
            case .setupEmail2FA:
                try await emailVerificationManager.setup2FA()
            case .disableEmail2FA:
                // No need to send code for disable - user should have received it via email
                break
            case .setupTOTP, .disableTOTP, .totpLogin:
                // TOTP codes are generated by the authenticator app
                break
            }
            
            // Start timers
            startExpirationTimer()
            resendCooldown = 120 // Default cooldown
            startResendCooldown()
            
            // Reset attempts for email verification when successfully sending new code
            if type.isEmailVerification {
                attemptsRemaining = 3
            }
            
        } catch let error as NetworkError {
            showError = true
            if case .clientError(let statusCode, _, let headers, _) = error, statusCode == 429 {
                if let retryAfterStr = headers["Retry-After"], let retryAfter = Int(retryAfterStr) {
                    resendCooldown = retryAfter
                    errorMessage = "Please wait \(formatTime(retryAfter)) before requesting another code."
                } else {
                    resendCooldown = 120 // Default to 2 minutes if no Retry-After header
                    errorMessage = "Too many requests. Please wait before trying again."
                }
                startResendCooldown()
            } else {
                errorMessage = "Failed to send verification code. Please try again."
            }
        } catch {
            showError = true
            errorMessage = "An unexpected error occurred. Please try again."
        }
    }
}

#if DEBUG
import Networking

#Preview {
    // Create shared dependencies
    let tokenStore = PreviewTokenStore()
    let refreshClient = PreviewRefreshAPIClient()
    let authorizationManager = AuthorizationManager(
        refreshClient: refreshClient,
        tokenStore: tokenStore
    )

    let totpService = PreviewTOTPService()
    let totpManager = TOTPManager(totpService: totpService)
    let emailVerificationService = PreviewEmailVerificationService()
    let emailVerificationManager = EmailVerificationManager(emailVerificationService: emailVerificationService)

    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        authorizationManager: authorizationManager
    )

    VerificationView(type: .totpLogin(tempToken: "preview-token"))
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif
