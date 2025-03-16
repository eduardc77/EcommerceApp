import SwiftUI
import Combine

struct RegisterView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var formState = RegisterFormState()
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
            accountInfoFieldsSection
            securityFieldsSection
        }
        .navigationTitle("Create Account")
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
                Button("Register") {
                    formState.validateAll()
                    if formState.isValid {
                        Task {
                            await register()
                        }
                    }
                }
            }
        }
        .onDisappear {
            formState.reset()
            focusedField = nil
        }
        .alert("Registration Failed", isPresented: .init(
            get: { authManager.registrationError != nil },
            set: { if !$0 { authManager.registrationError = nil } }
        )) {
            Button("OK") {
                authManager.registrationError = nil
            }
        } message: {
            if let error = authManager.registrationError {
                Text(error.localizedDescription)
            }
        }

    }

    private var accountInfoFieldsSection: some View {
        Section("Account Information") {
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
        }
    }

    private var securityFieldsSection: some View {
        Section("Security") {
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

    private func register() async {
        await authManager.register(
            username: formState.username,
            displayName: formState.displayName,
            email: formState.email,
            password: formState.password
        )
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
    RegisterView()
        .environment(AuthenticationManager(
            authService: PreviewAuthenticationService(),
            userService: PreviewUserService(),
            totpService: PreviewTOTPService(),
            emailVerificationService: PreviewEmailVerificationService(),
            authorizationManager: authorizationManager
        ))
}
#endif

