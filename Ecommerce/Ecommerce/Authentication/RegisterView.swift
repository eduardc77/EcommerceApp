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
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                }
            }
            .alert("Registration Error", isPresented: .constant(authManager.error != nil)) {
                Button("OK") { authManager.error = nil }
            } message: {
                Text(authManager.error?.localizedDescription ?? "")
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

#Preview {
    RegisterView()
        .environment(AuthenticationManager(
            authService: PreviewAuthenticationService(),
            userService: PreviewUserService(),
            tokenStore: PreviewTokenStore(),
            totpService: PreviewTOTPService(),
            emailVerificationService: PreviewEmailVerificationService()
        ))
} 
