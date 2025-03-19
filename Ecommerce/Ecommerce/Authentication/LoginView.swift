import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @State private var formState = LoginFormState()
    @FocusState private var focusedField: Field?
    @State private var showError = false
    @State private var lockedIdentifier: String?
    @State private var remainingTime: Int?
    @State private var lockoutStartTime: Date?
    @State private var navigationPath = NavigationPath()
    @State private var authFlow: AuthFlow?

    private enum Field {
        case identifier
        case password
    }

    private enum AuthFlow: Identifiable {
        case totpVerification(tempToken: String)
        case emailVerification(tempToken: String)
        
        var id: String {
            switch self {
            case .totpVerification: return "totp"
            case .emailVerification: return "email"
            }
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Form {
                loginFieldsSection

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
                    loginButton
                } footer: {
                    HStack {
                        Button {
                            navigationPath.append("register")
                        } label: {
                            Text("Create Account")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            navigationPath.append("forgot-password")
                        } label: {
                            Text("Forgot Password?")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Login")
            .navigationDestination(for: String.self) { route in
                switch route {
                case "register":
                    RegisterView()
                case "forgot-password":
                    Text("")
                default:
                    EmptyView()
                }
            }
            .sheet(item: $authFlow) { flow in
                switch flow {
                case .totpVerification(let token):
                    TOTPVerificationView(tempToken: token)
                case .emailVerification(let token):
                    EmailVerificationView(source: .login2FA, tempToken: token)
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
            .onChange(of: authManager.loginError) { _, error in
                if case .accountLocked(let retryAfter) = error,
                   let retryAfter = retryAfter {
                    lockoutStartTime = Date()
                    lockedIdentifier = formState.identifier
                    remainingTime = retryAfter
                    startTimer()
                }
            }
            .onChange(of: authManager.requiresTOTPVerification) { _, requiresTOTP in
                if requiresTOTP, let token = authManager.pendingLoginResponse?.tempToken {
                    authFlow = .totpVerification(tempToken: token)
                }
            }
            .onChange(of: authManager.requires2FAEmailVerification) { _, requiresEmail in
                if requiresEmail, let token = authManager.pendingLoginResponse?.tempToken {
                    authFlow = .emailVerification(tempToken: token)
                }
            }
            .onDisappear {
                formState.reset()
                focusedField = nil
                lockedIdentifier = nil
                remainingTime = nil
                lockoutStartTime = nil
            }
            .alert("Login Failed", isPresented: .init(
                get: { authManager.loginError != nil },
                set: { if !$0 { authManager.loginError = nil } }
            )) {
                Button("OK") {
                    authManager.loginError = nil
                }
            } message: {
                if let error = authManager.loginError {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private var loginFieldsSection: some View {
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

    private var loginButton: some View {
        AsyncButton("Login") {
            formState.validateAll()
            if formState.isValid {
                await login()
            }
        }
        .buttonStyle(.bordered)
        .disabled(lockedIdentifier == formState.identifier && remainingTime != nil)
    }

    private func login() async {
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

    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        authorizationManager: authorizationManager
    )

    LoginView()
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif
