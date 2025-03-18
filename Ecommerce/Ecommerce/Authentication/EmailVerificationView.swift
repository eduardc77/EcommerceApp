import SwiftUI

enum VerificationSource {
    case registration    // During initial registration
    case account        // From account settings
    case emailUpdate    // After email update
}

struct EmailVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(\.dismiss) private var dismiss

    let source: VerificationSource

    @State private var verificationCode = ""
    @State private var isShowingSkipAlert = false
    @State private var isResendingCode = false
    @State private var expirationTimer = codeExpirationTime
    @State private var resendCooldown = 0
    @State private var isExpirationTimerRunning = false
    @State private var attempts = 0
    @State private var showError = false
    @State private var errorMessage = ""

    // Constants
    private static let codeExpirationTime = 300 // 5 minutes
    private static let resendCooldownTime = 120 // 2 minutes
    private let codeLength = 6
    private let maxAttempts = 3
    @FocusState private var isCodeFieldFocused: Bool

    var body: some View {
        Form {
            headerSection
            codeInputSection
            actionButtonsSection
        }
        .onChange(of: verificationCode) { oldValue, newValue in
            handleCodeChange(oldValue: oldValue, newValue: newValue)
        }
        .onAppear {
            handleOnAppear()
        }
        .alert("Skip Verification?", isPresented: $isShowingSkipAlert) {
            skipVerificationAlert
        } message: {
            Text("You can still use the app, but some features will be limited until you verify your email.")
        }
    }

    // MARK: - View Sections

    private var headerSection: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "envelope.badge.shield.half.filled.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)

                VStack(spacing: 10) {
                    Text("Verify Your Email")
                        .font(.title)
                        .fontWeight(.bold)

                    if let email = authManager.currentUser?.email {
                        Text("We've sent a verification code to **\(email)**. Please enter it below to verify your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        } footer: {
            if isExpirationTimerRunning {
                Text("Code expires in \(formatTime(expirationTimer))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowSeparator(.hidden)
        .listRowInsets(.init())
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    private var codeInputSection: some View {
        Section {
            OneTimeCodeInput(code: $verificationCode, codeLength: codeLength)
                .focused($isCodeFieldFocused)
        } footer: {
            if showError {
                Text(errorMessage)
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .listRowInsets(.init())
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    private var actionButtonsSection: some View {
        Section {
            VStack(spacing: 16) {
                resendButton
                verifyButton
            }
        } footer: {
            VStack(spacing: 5) {
                if attempts > 0 {
                    Text("\(maxAttempts - attempts) attempts remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button(action: { isShowingSkipAlert = true }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 5)
            }
        }
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
    }

    private var resendButton: some View {
        Group {
            if resendCooldown > 0 {
                Text("Resend available in \(formatTime(resendCooldown))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                AsyncButton("Resend Code", font: .footnote) {
                    await resendCode()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(isResendingCode)
            }
        }
    }

    private var verifyButton: some View {
        AsyncButton("Verify") {
            await verifyCode()
        }
        .buttonStyle(.bordered)
        .disabled(verificationCode.count != codeLength || attempts >= maxAttempts)
    }

    private var skipVerificationAlert: some View {
        Group {
            Button("Continue without verifying", role: .destructive) {
                emailVerificationManager.skipEmailVerification()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Event Handlers

    private func handleCodeChange(oldValue: String, newValue: String) {
        // Only clear error if user is actively typing a new code
        if newValue.count > oldValue.count {
            showError = false
            errorMessage = ""
        }
    }

    private func handleOnAppear() {
        isCodeFieldFocused = true

        switch source {
        case .registration:
            // Code already sent during registration, just start timers
            startExpirationTimer()
            startResendCooldown()
        case .account, .emailUpdate:
            // Send new code and start timers
            Task {
                if let email = authManager.currentUser?.email {
                    await emailVerificationManager.resendVerificationEmail(email: email)
                    if emailVerificationManager.verificationError == nil {
                        startExpirationTimer()
                        startResendCooldown()
                    } else {
                        errorMessage = emailVerificationManager.verificationError?.localizedDescription ?? VerificationError.unknown("Failed to send verification code").localizedDescription
                        showError = true
                    }
                }
            }
        }
    }

    private func startExpirationTimer() {
        expirationTimer = Self.codeExpirationTime
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
        resendCooldown = Self.resendCooldownTime

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

    private func verifyCode() async {
        guard attempts < maxAttempts else {
            withAnimation {
                errorMessage = VerificationError.tooManyAttempts.localizedDescription
                showError = true
            }
            return
        }
        attempts += 1
        let success = await emailVerificationManager.verifyEmail(email: authManager.currentUser?.email ?? "", code: verificationCode)

        if success {
            // Only set authenticated if this is from registration
            if source == .registration {
                authManager.isAuthenticated = true
            }
            dismiss()
        } else {
            withAnimation {
                errorMessage = emailVerificationManager.verificationError?.localizedDescription ?? VerificationError.unknown("Verification failed").localizedDescription
                showError = true
                verificationCode = ""  // Clear code after setting error

                // If max attempts reached, stop the timer
                if attempts >= maxAttempts {
                    isExpirationTimerRunning = false
                }
            }
        }
    }

    private func resendCode() async {
        isResendingCode = true
        if let email = authManager.currentUser?.email {
            await emailVerificationManager.resendVerificationEmail(email: email)

            if emailVerificationManager.verificationError == nil {
                withAnimation {
                    attempts = 0
                    showError = false
                    errorMessage = ""
                    verificationCode = ""
                    startExpirationTimer()
                    startResendCooldown()
                }
            } else {
                withAnimation {
                    errorMessage = emailVerificationManager.verificationError?.localizedDescription ?? VerificationError.unknown("Failed to resend code").localizedDescription
                    showError = true
                }
            }
        }
        isResendingCode = false
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

    EmailVerificationView(source: .registration)
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif
