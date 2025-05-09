import SwiftUI

struct VerificationView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(\.dismiss) private var dismiss

    let type: VerificationType
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var isResendingCode = false
    @State private var resendCooldown = 0
    @State private var expirationTimer = 300 // 5 minutes
    @State private var isExpirationTimerRunning = false
    @State private var showingSkipAlert = false
    @State private var attemptsRemaining = 3 // Track remaining attempts
    @State private var showMFAEnabledAlert = false
    @FocusState private var isCodeFieldFocused: Bool
    @State private var isInitialSend = true
    @State private var showRecoveryCodesSheet = false
    @State private var shouldSignOutAfterDismiss = false

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
            .task {
                // Don't send code if MFA is already verified
                if isInitialSend {
                    await handleInitialCodeSending()
                }
            }
            .alert("Skip Verification", isPresented: $showingSkipAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Skip", role: .destructive) {
                    emailVerificationManager.skipVerification()
                    // If we have pending credentials, sign in the user
                    if let credentials = authManager.pendingCredentials {
                        Task {
                            await authManager.signIn(identifier: credentials.identifier, password: credentials.password)
                        }
                    }
                    dismiss()
                }
            } message: {
                Text("You can verify your email later from your account settings.")
            }
            .alert("MFA Enabled Successfully", isPresented: $showMFAEnabledAlert) {
                Button("Continue") {
                    showRecoveryCodesSheet = true
                }
            } message: {
                Text("Your account is now more secure. Recovery codes have been generated. Store these recovery codes in a safe place - they allow you to access your account if you lose access to your MFA device.")
            }
        }
        .sheet(isPresented: $showRecoveryCodesSheet, onDismiss: {
            if shouldSignOutAfterDismiss {
                authManager.isAuthenticated = false
                dismiss()
            }
        }) {
            RecoveryCodesView(shouldLoadCodesOnAppear: false)
                .interactiveDismissDisabled()
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
            if type.isRecoveryCode {
                TextField("xxxx-xxxx-xxxx-xxxx", text: $verificationCode)
                    .textContentType(.oneTimeCode)
                    .font(.system(.body, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .focused($isCodeFieldFocused)
                    .onChange(of: verificationCode) { oldValue, newValue in
                        verificationCode = formatRecoveryCode(newValue)
                    }
            } else {
                OneTimeCodeInput(code: $verificationCode, codeLength: 6)
                    .focused($isCodeFieldFocused)
                    .frame(maxWidth: .infinity)
            }
        } footer: {
            VStack {
                if showError {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.red)
                }
                if showSuccess {
                    Text(successMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.green)
                }
                if attemptsRemaining < 3 && type.isEmail {
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
                .disabled(
                    (type.isRecoveryCode && !isValidRecoveryCode) ||
                    (!type.isRecoveryCode && verificationCode.count != 6) ||
                    isLoading ||
                    (type.isEmail && attemptsRemaining == 0)
                )

                if type.showsSkipButton {
                    Button {
                        showingSkipAlert = true
                    } label: {
                        Text("Skip for now")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
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
                    isInitialSend = false  // Mark as resend when using resend button
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
            case .initialEmail(let stateToken, let email):
                let response = try await emailVerificationManager.verifyInitialEmail(code: verificationCode, stateToken: stateToken, email: email)
                await authManager.completeSignIn(response: response)
                dismiss()
            case .initialEmailFromAccountSettings(let email):
                _ = try await emailVerificationManager.verifyInitialEmail(code: verificationCode, stateToken: "", email: email)
                // Refresh profile to update UI state
                await authManager.refreshProfile()
                dismiss()
            case .enableEmailMFA(let email):
                let codes = try await emailVerificationManager.verifyEmailMFA(code: verificationCode, email: email)
                authManager.recoveryCodesManager.codes = codes
                shouldSignOutAfterDismiss = true
                // Only show recovery codes alert if codes were actually generated
                if !codes.isEmpty {
                    showMFAEnabledAlert = true
                } else {
                    // Just show a simple success message and sign out
                    showSuccess = true
                    successMessage = "Email MFA has been enabled successfully."
                    // Sign out after a short delay
                    authManager.isAuthenticated = false
                }
            case .enableTOTP:
                let codes = try await authManager.totpManager.verifyTOTP(code: verificationCode)
                authManager.recoveryCodesManager.codes = codes
                shouldSignOutAfterDismiss = true
                // Only show recovery codes alert if codes were actually generated
                if !codes.isEmpty {
                    showMFAEnabledAlert = true
                } else {
                    // Just show a simple success message and sign out
                    showSuccess = true
                    successMessage = "Authenticator app has been enabled successfully."
                    // Sign out after a short delay
                    authManager.isAuthenticated = false
                }
            default:
                try await authManager.completeMFAVerification(for: type, code: verificationCode)
                dismiss()
            }
        } catch let error as NetworkError {
            print("DEBUG: Network error in verify(): \(error)")
            // Show errors for sign-in/sign-up verification regardless of auth state
            let shouldShowError = type.isSignInOrSignUp || authManager.isAuthenticated
            if shouldShowError {
                showError = true
                if case .badRequest(let description) = error, description.contains("No verification code found") {
                    // Reset verification state and request new code
                    verificationCode = ""
                    if type.isEmail {
                        attemptsRemaining = 3 // Reset attempts for email verification
                    }
                    errorMessage = "Too many failed attempts. A new code has been requested."
                    Task {
                        await sendCode() // Request a new verification code
                    }
                } else if case .unauthorized(let description) = error, description.contains("session expired") || description.contains("state token expired") {
                    // Handle expired state token
                    verificationCode = ""
                    errorMessage = "Your verification session has expired. Please start the sign-in process again."
                    // Dismiss after a short delay to allow user to read the message
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        dismiss()
                    }
                } else if case .badRequest = error {
                    // Handle invalid verification code
                    if type.isEmail {
                        attemptsRemaining -= 1 // Decrement attempts only for email verification
                        if attemptsRemaining == 0 {
                            errorMessage = "Too many failed attempts. Please generate a new code."
                        } else {
                            errorMessage = type.errorMessage
                        }
                    } else {
                        errorMessage = type.errorMessage
                    }
                }
            }
        } catch {
            // Show errors for sign-in/sign-up verification regardless of auth state
            let shouldShowError = type.isSignInOrSignUp || authManager.isAuthenticated
            if shouldShowError {
                showError = true
                if type.isEmail {
                    attemptsRemaining -= 1
                }
                errorMessage = type.errorMessage
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

    private func handleInitialCodeSending() async {
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

    private func sendCode() async {
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
            
            // Start timers for all email verification cases
            if type.isEmail {
                startTimers()
            }
            
            // Show success message for resends
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
    
    /// Starts both expiration and resend cooldown timers
    private func startTimers() {
        startExpirationTimer()
        resendCooldown = 120 // 2 minutes cooldown
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
            // No initial code needed for the rest of the cases
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
            resendCooldown = 120 // Default to 2 minutes if no Retry-After header
            errorMessage = "Too many requests. Please wait before trying again."
        }
        startResendCooldown()
    }
    
    private func handleUnexpectedError() {
        showError = true
        errorMessage = "An unexpected error occurred. Please try again."
    }

    private func handleVerificationError(_ error: Error) {
        showError = true
        errorMessage = "Verification error. Please try again later."
    }

    // Add recovery code formatting logic
    private var isValidRecoveryCode: Bool {
        let cleaned = verificationCode.filter { $0.isNumber || $0.isLetter }
        return cleaned.count == 16
    }

    private func formatRecoveryCode(_ code: String) -> String {
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
    let recoeryCodesService = PreviewRecoveryCodesService()
    let recoveryCodesManager = RecoveryCodesManager(recoveryCodesService: recoeryCodesService)

    let authManager = AuthManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        recoveryCodesManager: recoveryCodesManager,
        authorizationManager: authorizationManager
    )

    VerificationView(type: .totpSignIn(stateToken: "preview-token"))
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif
