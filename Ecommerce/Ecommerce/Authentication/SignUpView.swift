import SwiftUI

struct SignUpView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @State private var formState = SignUpFormState()
    @FocusState private var focusedField: Field?
    @State private var showError = false

    private enum Field {
        case username
        case displayName
        case email
        case password
        case confirmPassword
    }

    var body: some View {
        Form {
            signUpFieldsSection
        }
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
                withAnimation(.smooth) {
                    switch oldValue {
                    case .username: formState.validateUsername(ignoreEmpty: true)
                    case .displayName: formState.validateDisplayName(ignoreEmpty: true)
                    case .email: formState.validateEmail(ignoreEmpty: true)
                    case .password: formState.validatePassword(ignoreEmpty: true)
                    case .confirmPassword: formState.validateConfirmPassword(ignoreEmpty: true)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    formState.validateAll()
                    if formState.isValid {
                        Task {
                            await signUp()
                        }
                    }
                }
                .fontWeight(.medium)
            }
        }
        .onDisappear {
            formState.reset()
            focusedField = nil
        }
        .alert("Sign Up Failed", isPresented: .init(
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

    private var signUpFieldsSection: some View {
        Section {
            ValidatedFormField(
                title: "Username",
                text: $formState.username,
                field: Field.username,
                focusedField: $focusedField,
                error: formState.fieldErrors["username"],
                validate: { formState.validateUsername() },
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
                title: "Email",
                text: $formState.email,
                field: Field.email,
                focusedField: $focusedField,
                error: formState.fieldErrors["email"],
                validate: { formState.validateEmail() },
                capitalization: .never
            )
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
                title: "Confirm Password",
                text: $formState.confirmPassword,
                field: Field.confirmPassword,
                focusedField: $focusedField,
                error: formState.fieldErrors["confirmPassword"],
                validate: { formState.validateConfirmPassword() },
                secureField: true
            )
        }
    }

    private func signUp() async {
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

    let authManager = AuthenticationManager(
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

