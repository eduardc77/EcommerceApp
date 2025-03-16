import SwiftUI

struct RegisterView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Username", text: $username)
                        .textContentType(.username)
                        .autocapitalization(.none)

                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                Section("Security") {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
            }
            .navigationTitle("Create Account")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Register", action: register)
                        .disabled(!isValid)
                }
            }
            .alert("Registration Error", isPresented: .constant(authManager.registrationError != nil)) {
                Button("OK") { authManager.registrationError = nil }
            } message: {
                Text(authManager.registrationError?.localizedDescription ?? "")
            }
        }
    }
    
    private var isValid: Bool {
        !displayName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty && 
        password == confirmPassword
    }
    
    private func register() {
        Task {
            await authManager.register(
                username: username,
                displayName: displayName,
                email: email,
                password: password
            )
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
