import SwiftUI

struct RegisterView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Personal Information") {
                    TextField("Username", text: $username)
                        .textContentType(.name)

                    TextField("Display Name", text: $displayName)
                        .textContentType(.name)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Section("Security") {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
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
            dismiss()
        }
    }
} 
