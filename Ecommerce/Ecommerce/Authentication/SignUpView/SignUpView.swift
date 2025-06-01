import SwiftUI
import Networking

struct SignUpView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @State private var formState = SignUpFormState()
    @State private var termsAccepted = false
    @FocusState private var focusedField: Field?
    @State private var showError = false
    
    private enum Field {
        case username
        case displayName
        case email
        case password
        case confirmPassword
    }
    
    private var hasEmptyFields: Bool {
        formState.username.isEmpty ||
        formState.displayName.isEmpty ||
        formState.email.isEmpty ||
        formState.password.isEmpty ||
        formState.confirmPassword.isEmpty
    }
    
    var body: some View {
        Form {
            headerSection
            personalInfoSection
            securitySection
            termsAcceptanceSection
            privacyFooter
        }
        .listSectionSpacing(20)
        .navigationTitle("Sign Up")
        .sheet(isPresented: .init(
            get: { emailVerificationManager.requiresEmailVerification },
            set: { newValue in
                if !newValue {
                    emailVerificationManager.requiresEmailVerification = false
                }
            }
        )) {
            VerificationView(type: .initialEmail(stateToken: authManager.pendingSignInResponse?.stateToken ?? "", email: formState.email))
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if let oldValue = oldValue {
                withAnimation {
                    switch oldValue {
                    case .username: formState.validateUsername()
                    case .displayName: formState.validateDisplayName()
                    case .email: formState.validateEmail()
                    case .password: formState.validatePassword()
                    case .confirmPassword: formState.validateConfirmPassword()
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Continue") {
                    formState.validateAll()
                    if !hasEmptyFields {
                        Task {
                            await signUp()
                        }
                    }
                }
                .fontWeight(.medium)
                .disabled(hasEmptyFields)
            }
        }
        .onDisappear {
            formState.reset()
            focusedField = nil
        }
        .alert("Error", isPresented: .init(
            get: { authManager.signUpError != nil },
            set: { if !$0 { authManager.signUpError = nil } }
        )) {
            Button("OK") {
                authManager.signUpError = nil
            }
        } message: {
            if let error = authManager.signUpError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var headerSection: some View {
        Section {
            Text("Create your account to access our platform and services.")
                .multilineTextAlignment(.center)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        }
    }
    
    private var personalInfoSection: some View {
        Section {
            ValidatedFormField(
                title: "Email",
                text: $formState.email,
                field: Field.email,
                focusedField: $focusedField,
                error: formState.fieldErrors["email"],
                validate: { formState.validateEmail() },
                capitalization: .never
            )
            ValidatedFormField(
                title: "Display Name",
                text: $formState.displayName,
                field: Field.displayName,
                focusedField: $focusedField,
                error: formState.fieldErrors["displayName"],
                validate: { formState.validateDisplayName() }
            )
            ValidatedFormField(
                title: "Username",
                text: $formState.username,
                field: Field.username,
                focusedField: $focusedField,
                error: formState.fieldErrors["username"],
                validate: { formState.validateUsername() },
                capitalization: .never
            )
        }
    }
    
    private var securitySection: some View {
        Section {
            ValidatedFormField(
                title: "Password",
                text: $formState.password,
                field: Field.password,
                focusedField: $focusedField,
                error: formState.fieldErrors["password"],
                validate: { formState.validatePassword() },
                secureField: true,
                isNewPassword: true
            )
            ValidatedFormField(
                title: "Retype Password",
                text: $formState.confirmPassword,
                field: Field.confirmPassword,
                focusedField: $focusedField,
                error: formState.fieldErrors["confirmPassword"],
                validate: { formState.validateConfirmPassword() },
                secureField: true
            )
        } footer: {
            if focusedField == .password {
                PasswordRequirementsFooter(password: formState.password)
            }
        }
    }
    
    private var termsAcceptanceFooter: some View {
        Text("By creating an account, you acknowledge that you agree to the [Terms of Service](terms) and [Privacy Policy](privacy).")
            .font(.footnote)
            .environment(\.openURL, OpenURLAction { url in
                switch url.absoluteString {
                case "terms":
                    print("Terms of Service tapped")
                    return .handled
                case "privacy":
                    print("Privacy Policy tapped")
                    return .handled
                default:
                    return .systemAction
                }
            })
    }
    
    private var termsAcceptanceSection: some View {
        Section {
            Toggle("Agree to Terms and Conditions", isOn: $termsAccepted)
                .font(.subheadline)
                .foregroundStyle(.primary)
        } footer: {
            termsAcceptanceFooter
        }
    }
    
    private var privacyFooter: some View {
        Section {
            VStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
                    .font(.subheadline)
                
                Text("We're committed to protecting your personal information and being transparent about how we use it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 8, trailing: 16))
    }
    
    
    private func signUp() async {
        // Check if terms are accepted first
        guard termsAccepted else {
            authManager.signUpError = .termsNotAccepted
            return
        }
        
        // Check if form is valid
        guard formState.isValid else {
            return
        }
        
        do {
            try await authManager.signUp(
                username: formState.username,
                email: formState.email,
                password: formState.password,
                displayName: formState.displayName
            )
        } catch let networkError as NetworkError {
            switch networkError {
            case let .clientError(statusCode, description, _, _):
                switch statusCode {
                case 409:
                    authManager.signUpError = .accountExists
                case 422:
                    authManager.signUpError = .validationError(description)
                default:
                    authManager.signUpError = .unknown(description)
                }
            default:
                authManager.signUpError = .unknown(networkError.localizedDescription)
            }
        } catch {
            // Handle any other errors
            authManager.signUpError = .unknown(error.localizedDescription)
        }
    }
}

#if DEBUG
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
    
    NavigationStack {
        SignUpView()
            .environment(authManager)
            .environment(emailVerificationManager)
    }
}
#endif

