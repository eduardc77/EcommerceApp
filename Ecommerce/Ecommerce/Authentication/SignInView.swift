import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(SocialAuthManager.self) private var socialAuthManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    @State private var formState = SignInFormState()
    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var lockedIdentifier: String?
    @State private var remainingTime: Int?
    @State private var lockoutStartTime: Date?
    @State private var pendingStateToken: String?
    
    private enum Field {
        case identifier
        case password
    }
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        NavigationStack(path: $bindableCoordinator.navigationPath) {
            Form {
                signInFieldsSection
                
                if let remainingTime = remainingTime, lockedIdentifier == formState.identifier {
                    Section {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Account locked for ")
                            Text(formatTime(remainingTime))
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(.red)
                    }
                }
                
                Section {
                    signInButton
                } footer: {
                    HStack {
                        Button {
                            coordinator.navigateToSignUp()
                        } label: {
                            Text("Create Account")   
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        Button {
                            coordinator.navigateToForgotPassword()
                        } label: {
                            Text("Forgot Password?")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .font(.subheadline)
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                    .padding(.bottom)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
                
                Section {
                    VStack {
                        AsyncButton("Sign in with Google") {
                            await socialAuthManager.signInWithGoogle()
                        }
                        
                        AsyncButton("Sign in with Apple") {
                            // TODO: Implement Apple Sign In
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } header: {
                    VStack {
                        Divider()
                        Text("Or")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Sign In")
            .navigationDestination(for: AuthenticationCoordinator.Route.self) { route in
                switch route {
                case .signup:
                    SignUpView()
                case .forgotPassword:
                    ForgotPasswordView()
                case .resetPassword(let email):
                    ResetPasswordView(email: email)
                }
            }
            .sheet(item: $bindableCoordinator.authFlow) { flow in
                switch flow {
                case .totpVerification(let token):
                    VerificationView(type: .totpSignIn(stateToken: token))
                case .emailVerification(let token):
                    VerificationView(type: .emailSignIn(stateToken: token))
                case .mfaSelection(let token):
                    MFASelectionView(stateToken: token) { option in
                        switch option {
                        case .totp:
                            coordinator.showTOTPVerification(stateToken: token)
                        case .email:
                            coordinator.showEmailVerification(stateToken: token)
                        case .recoveryCode:
                            coordinator.showRecoveryCodeVerification(stateToken: token)
                        }
                    }
                case .recoveryCodeVerification(let token):
                    RecoveryCodeEntryView(stateToken: token)
                case .resetPassword:
                    EmptyView() // This is handled by navigationDestination
                }
            }
            .onChange(of: focusedField) { oldValue, newValue in
                if let oldValue = oldValue {
                    switch oldValue {
                    case .identifier: formState.validateIdentifier(ignoreEmpty: true)
                    case .password: formState.validatePassword(ignoreEmpty: true)
                    }
                }
            }
            .onChange(of: formState.identifier) { _, _ in
                // Clear lockout if identifier changes
                if formState.identifier != lockedIdentifier {
                    lockedIdentifier = nil
                    remainingTime = nil
                    lockoutStartTime = nil
                }
            }
            .onChange(of: authManager.signInError) { _, error in
                if case .accountLocked(let retryAfter) = error,
                   let retryAfter = retryAfter {
                    lockoutStartTime = Date()
                    lockedIdentifier = formState.identifier
                    remainingTime = retryAfter
                    startTimer()
                }
            }
            .onChange(of: authManager.availableMFAMethods) { _, methods in
                if !methods.isEmpty, let token = authManager.pendingSignInResponse?.stateToken {
                    if methods.count > 1 {
                        coordinator.showMFASelection(stateToken: token)
                    } else if methods.contains(.totp) {
                        coordinator.showTOTPVerification(stateToken: token)
                    } else if methods.contains(.email) {
                        coordinator.showEmailVerification(stateToken: token)
                    }
                }
            }
            .onChange(of: authManager.requiresTOTPVerification) { _, requiresTOTP in
                if requiresTOTP, let token = authManager.pendingSignInResponse?.stateToken {
                    if authManager.requiresEmailMFAVerification {
                        coordinator.showMFASelection(stateToken: token)
                    } else {
                        coordinator.showTOTPVerification(stateToken: token)
                    }
                }
            }
            .onChange(of: authManager.requiresEmailMFAVerification) { _, requiresEmail in
                if requiresEmail, let token = authManager.pendingSignInResponse?.stateToken {
                    if authManager.requiresTOTPVerification {
                        coordinator.showMFASelection(stateToken: token)
                    } else {
                        coordinator.showEmailVerification(stateToken: token)
                    }
                }
            }
            
            .onDisappear {
                formState.reset()
                focusedField = nil
                lockedIdentifier = nil
                remainingTime = nil
                lockoutStartTime = nil
            }
            .alert("Sign In Failed", isPresented: .init(
                get: { authManager.signInError != nil },
                set: { if !$0 { authManager.signInError = nil } }
            )) {
                Button("OK") {
                    authManager.signInError = nil
                }
            } message: {
                if let error = authManager.signInError {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private var signInFieldsSection: some View {
        Section {
            ValidatedFormField(
                title: "Username or Email",
                text: $formState.identifier,
                field: Field.identifier,
                focusedField: $focusedField,
                error: formState.fieldErrors["identifier"],
                validate: { formState.validateIdentifier() },
                capitalization: .never
            )
            
            ValidatedFormField(
                title: "Password",
                text: $formState.password,
                field: Field.password,
                focusedField: $focusedField,
                error: formState.fieldErrors["password"],
                validate: { formState.validatePassword() },
                secureField: true
            )
        }
    }
    
    private var signInButton: some View {
        AsyncButton("Sign In") {
            formState.validateAll()
            if formState.isValid {
                await signIn()
            }
        }
        .buttonStyle(.bordered)
        .disabled(lockedIdentifier == formState.identifier && remainingTime != nil)
    }
    
    private func signIn() async {
        await authManager.signIn(
            identifier: formState.identifier,
            password: formState.password
        )
    }
    
    private func startTimer() {
        guard let startTime = lockoutStartTime,
              let totalDuration = remainingTime else { return }
        
        // Calculate actual remaining time based on how long it's been since we got the error
        let elapsed = Int(-startTime.timeIntervalSinceNow)
        remainingTime = max(0, totalDuration - elapsed)
        
        Task {
            while remainingTime ?? 0 > 0 {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    remainingTime? -= 1
                    if remainingTime == 0 {
                        remainingTime = nil
                        lockedIdentifier = nil
                        lockoutStartTime = nil
                    }
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
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
    
    let socialAuthManager = SocialAuthManager(authManager: authManager)
    
    SignInView()
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
        .environment(socialAuthManager)
}
#endif
