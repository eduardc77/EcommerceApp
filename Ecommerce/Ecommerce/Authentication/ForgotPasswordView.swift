import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var fieldError: String?
    
    private enum Field {
        case email
    }
    
    var body: some View {
        @Bindable var bindableCoordinator = coordinator
        
        Form {
            Text("Enter your email address and we'll send you instructions to reset your password.")
                .foregroundStyle(.secondary)
                .listRowInsets(.init())
                .listRowBackground(Color.clear)

            Section {
                ValidatedFormField(
                    title: "Email",
                    text: $email,
                    field: Field.email,
                    focusedField: $focusedField,
                    error: fieldError,
                    validate: { validateEmail() },
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    capitalization: .never
                )
            }
            Section {
                AsyncButton("Send Reset Instructions") {
                    await sendResetInstructions()
                }
                .buttonStyle(.bordered)
                .disabled(email.isEmpty || isLoading || !isValidEmail(email))
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
        }
        .listRowSeparator(.hidden)
        .navigationTitle("Reset Password")
        .alert("Check Your Email", isPresented: $showSuccess) {
            Button("Continue") {
                showSuccess = false
                coordinator.navigateToResetPassword(email: email)
            }
        } message: {
            Text("If an account exists with that email, we've sent you instructions to reset your password.")
        }
        .alert("Error", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .email {
                validateEmail()
            }
        }
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private func sendResetInstructions() async {
        validateEmail()
        guard isValidEmail(email) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.requestPasswordReset(email: email)
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func validateEmail() {
        if email.isEmpty {
            fieldError = "Email is required"
        } else if !isValidEmail(email) {
            fieldError = "Please enter a valid email address"
        } else {
            fieldError = nil
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
