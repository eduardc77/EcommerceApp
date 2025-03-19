import SwiftUI

public enum VerificationSource {
    case registration    // During initial registration
    case account        // From account settings
    case emailUpdate    // After email update
    case login2FA       // During login with 2FA
}

struct EmailVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(\.dismiss) private var dismiss

    let source: VerificationSource
    let tempToken: String?
    
    init(source: VerificationSource, tempToken: String? = nil) {
        self.source = source
        self.tempToken = tempToken
    }

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
                    Text(headerTitle)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(headerMessage)
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
        .listRowSeparator(.hidden)
        .listRowInsets(.init())
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
    }

    private var headerTitle: String {
        switch source {
        case .login2FA:
            return "Two-Factor Authentication"
        default:
            return "Verify Your Email"
        }
    }

    private func markdownString(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }

    private var headerMessage: AttributedString {
        switch source {
        case .login2FA:
            return markdownString("Please enter the verification code sent to your email to complete login.")
        default:
            if let email = authManager.currentUser?.email {
                return markdownString("We've sent a verification code to **\(email)**. Please enter it below to verify your account.")
            }
            return markdownString("We've sent a verification code to your email. Please enter it below to verify your account.")
        }
    }

    private var codeInputSection: some View {
        Section {
            OneTimeCodeInput(code: $verificationCode, codeLength: codeLength)
                .focused($isCodeFieldFocused)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
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
                if shouldShowSkipButton {
                    Button(action: { isShowingSkipAlert = true }) {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 5)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .listRowSeparator(.hidden)
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
    }

    private var shouldShowSkipButton: Bool {
        switch source {
        case .login2FA:
            return false
        default:
            return true
        }
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
                if source == .registration {
                    authManager.isAuthenticated = true
                }
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
        case .login2FA, .registration:
            // Code already sent during registration, just start timers
            startExpirationTimer()
            startResendCooldown()
        case .account, .emailUpdate:
            // Send new code and start timers
            Task {
                if let email = authManager.currentUser?.email {
                    do {
                        try await emailVerificationManager.resendVerificationEmail(email: email)
                        startExpirationTimer()
                        startResendCooldown()
                    } catch {
                        errorMessage = error.localizedDescription
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
        
        do {
            switch source {
            case .login2FA:
                guard let tempToken = tempToken else { return }
                try await authManager.verifyEmail2FALogin(code: verificationCode, tempToken: tempToken)
                authManager.isAuthenticated = true
                dismiss()
            case .registration:
                try await emailVerificationManager.verifyInitialEmail(email: authManager.currentUser?.email ?? "", code: verificationCode)
                authManager.isAuthenticated = true
                dismiss()
            default:
                try await emailVerificationManager.verifyInitialEmail(email: authManager.currentUser?.email ?? "", code: verificationCode)
                dismiss()
            }
        } catch {
            handleVerificationError(error)
        }
    }
    
    private func handleVerificationError(_ error: Error) {
        withAnimation {
            errorMessage = error.localizedDescription
            showError = true
            verificationCode = ""

            if attempts >= maxAttempts {
                isExpirationTimerRunning = false
            }
        }
    }

    private func resendCode() async {
        isResendingCode = true
        defer { isResendingCode = false }
        
        if let email = authManager.currentUser?.email {
            do {
                try await emailVerificationManager.resendVerificationEmail(email: email)
                withAnimation {
                    attempts = 0
                    showError = false
                    errorMessage = ""
                    verificationCode = ""
                    startExpirationTimer()
                    startResendCooldown()
                }
            } catch {
                withAnimation {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
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

    EmailVerificationView(source: .registration)
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif
