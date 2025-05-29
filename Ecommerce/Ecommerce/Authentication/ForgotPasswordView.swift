import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    @State private var email = ""
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var networkError: String?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var fieldError: String?
    
    private enum Field {
        case email
    }
    
    var body: some View {
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
                    validate: validateEmail,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    capitalization: .never
                )
            }
            Section {
                AsyncButton("Send Reset Instructions") {
                    validateEmail()
                    guard fieldError == nil else { return }
                    await sendResetInstructions()
                }
                .buttonStyle(.bordered)
                .disabled(email.isEmpty || isLoading || fieldError != nil)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
        }
        .listSectionSpacing(.compact)
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
        .alert("Reset Failed", isPresented: .init(
            get: { networkError != nil },
            set: { if !$0 { networkError = nil } }
        )) {
            Button("OK") {
                networkError = nil
            }
        } message: {
            if let error = networkError {
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
   
    @MainActor
    private func sendResetInstructions() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.sendPasswordResetInstructions(email: email)
            showSuccess = true
        } catch {
            if let authError = error as? LocalizedError, let desc = authError.errorDescription {
                networkError = desc
            } else {
                networkError = error.localizedDescription
            }
        }
    }
    
    @MainActor
    private func validateEmail() {
        let (_, error) = authManager.validateEmail(email)
        fieldError = error
    }
}
