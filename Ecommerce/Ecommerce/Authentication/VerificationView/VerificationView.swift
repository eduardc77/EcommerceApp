import SwiftUI

struct VerificationView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    let type: VerificationType

    var body: some View {
        VerificationViewContent(
            type: type,
            authManager: authManager,
            emailVerificationManager: emailVerificationManager
        )
    }
}

struct VerificationViewContent: View {
    let type: VerificationType
    let authManager: AuthManager
    let emailVerificationManager: EmailVerificationManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: VerificationViewModel
    @FocusState private var isCodeFieldFocused: Bool

    init(type: VerificationType, authManager: AuthManager, emailVerificationManager: EmailVerificationManager) {
        self.type = type
        self.authManager = authManager
        self.emailVerificationManager = emailVerificationManager
        _viewModel = State(initialValue: VerificationViewModel(
            type: type,
            authManager: authManager,
            emailVerificationManager: emailVerificationManager
        ))
    }

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
            .disabled(viewModel.isLoading)
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .task {
                if viewModel.isInitialSend {
                    await viewModel.handleInitialCodeSending()
                }
            }
            .alert("Skip Verification", isPresented: $viewModel.showingSkipAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Skip", role: .destructive) {
                    emailVerificationManager.skipVerification()
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
            .alert("MFA Enabled Successfully", isPresented: $viewModel.showMFAEnabledAlert) {
                Button("Continue") {
                    if viewModel.shouldShowRecoveryCodesSheetAfterAlert {
                        viewModel.showRecoveryCodesSheet = true
                    } else {
                        authManager.isAuthenticated = false
                        dismiss()
                    }
                }
            } message: {
                if viewModel.shouldShowRecoveryCodesSheetAfterAlert {
                    Text("Your account is now more secure. Recovery codes have been generated. Store these recovery codes in a safe place - they allow you to access your account if you lose access to your MFA device.")
                } else {
                    Text("Your account is now more secure with multiple MFA methods enabled.")
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccess) {
                Button("OK") {
                    if type.isSetup {
                        authManager.isAuthenticated = false
                        dismiss()
                    }
                }
            } message: {
                Text(viewModel.successMessage)
            }
        }
        .sheet(isPresented: $viewModel.showRecoveryCodesSheet, onDismiss: {
            authManager.isAuthenticated = false
            dismiss()
        }) {
            RecoveryCodesView(shouldLoadCodesOnAppear: false)
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
            if viewModel.isExpirationTimerRunning {
                Text("Code expires in \(viewModel.formatTime(viewModel.expirationTimer))")
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
            OneTimeCodeInput(code: $viewModel.verificationCode, codeLength: 6)
                .focused($isCodeFieldFocused)
                .frame(maxWidth: .infinity)
        } footer: {
            VStack {
                if viewModel.showError {
                    Text(viewModel.errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.red)
                } else if viewModel.showSuccess && !type.isSetup {
                    Text(viewModel.successMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.green)
                } else if viewModel.attemptsRemaining < 3 && type.isEmail {
                    Text("\(viewModel.attemptsRemaining) attempts remaining")
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
                    let success = await viewModel.verify()
                    if success {
                        if !type.isSetup {
                            dismiss()
                        }
                    }
                } label: {
                    Text(type.buttonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(
                    viewModel.verificationCode.count != 6 ||
                    viewModel.isLoading ||
                    (type.isEmail && viewModel.attemptsRemaining == 0)
                )

                if type.showsSkipButton {
                    Button {
                        viewModel.showingSkipAlert = true
                    } label: {
                        Text("Skip for now")
                            .frame(maxWidth: .infinity)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                
                if type.isSignIn  {
                    Button {
                        dismiss()
                        coordinator.showRecoveryCodeVerification(stateToken: type.stateToken)
                    } label: {
                        Text("Use Recovery Code")
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
            if viewModel.resendCooldown > 0 {
                Text("Resend available in \(viewModel.formatTime(viewModel.resendCooldown))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                AsyncButton("Resend Code", font: .footnote) {
                    viewModel.isInitialSend = false
                    await viewModel.sendCode()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .disabled(viewModel.isResendingCode)
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
