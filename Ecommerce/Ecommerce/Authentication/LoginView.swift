import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var formState = LoginFormState()
    @FocusState private var focusedField: Field?
    @State private var showError = false
    
    private enum Field {
        case email
        case password
    }
    
    var body: some View {
        NavigationStack {
            Form {
                formFieldsSection
                
                Section {
                    loginButton
                    
                    NavigationLink {
                        RegisterView()
                    } label: {
                        Text("Create Account")
                    }
                    .buttonStyle(.plain)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }
            .navigationTitle("Login")
            .onChange(of: focusedField) { oldValue, newValue in
                if let oldValue = oldValue {
                    switch oldValue {
                    case .email: formState.validateEmail(ignoreEmpty: true)
                    case .password: formState.validatePassword(ignoreEmpty: true)
                    }
                }
            }
            .onDisappear {
                formState.reset()
                focusedField = nil
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
    
    private var formFieldsSection: some View {
        Section {
            ValidatedFormField(
                title: "Email",
                text: $formState.email,
                field: Field.email,
                focusedField: $focusedField,
                error: formState.fieldErrors["email"],
                validate: { formState.validateEmail() }
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
    }
    
    private func login() async {
        await authManager.signIn(
            identifier: formState.email,
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
    LoginView()
        .environment(AuthenticationManager(
            authService: PreviewAuthenticationService(),
            userService: PreviewUserService(),
            totpService: PreviewTOTPService(),
            emailVerificationService: PreviewEmailVerificationService(),
            authorizationManager: authorizationManager
        ))
}
#endif
