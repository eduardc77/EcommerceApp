import SwiftUI
import Networking

// Add ErrorResponse struct for parsing backend errors
private struct ErrorResponse: Codable {
    let message: String
    let success: Bool
}

struct ChangePasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var formState = ResetPasswordFormState()
    @FocusState private var focusedField: ResetPasswordField?
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    init() {
        _formState = State(initialValue: {
            let state = ResetPasswordFormState()
            state.isChangePassword = true
            return state
        }())
    }
    
    var body: some View {
        List {
            Section {
                ValidatedFormField(
                    title: "Current Password",
                    text: $formState.currentPassword,
                    field: ResetPasswordField.currentPassword,
                    focusedField: $focusedField,
                    error: formState.fieldErrors["currentPassword"],
                    validate: { formState.validateCurrentPassword() },
                    secureField: true
                )
            }
            
            Section {
                ValidatedFormField(
                    title: "New Password",
                    text: $formState.newPassword,
                    field: ResetPasswordField.newPassword,
                    focusedField: $focusedField,
                    error: formState.fieldErrors["newPassword"],
                    validate: { formState.validateNewPassword() },
                    secureField: true,
                    isNewPassword: true
                )
                
                ValidatedFormField(
                    title: "Confirm Password",
                    text: $formState.confirmPassword,
                    field: ResetPasswordField.confirmPassword,
                    focusedField: $focusedField,
                    error: formState.fieldErrors["confirmPassword"],
                    validate: { formState.validateConfirmPassword() },
                    secureField: true
                )
            } footer: {
                Text("Your password must be at least 8 characters long, include a number, an uppercase letter, a lowercase letter, and a special character.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.blue)
            }
            
            ToolbarItem(placement: .confirmationAction) {
                AsyncButton("Change") {
                    await changePassword()
                }
                .disabled(!formState.isValid || isLoading)
                .foregroundStyle(!formState.isValid || isLoading ? .gray : .blue)
            }
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if let oldValue = oldValue {
                withAnimation(.smooth) {
                    switch oldValue {
                    case .code:
                        formState.validateCode()
                    case .newPassword:
                        formState.validateNewPassword()
                    case .confirmPassword:
                        formState.validateConfirmPassword()
                    case .currentPassword:
                        formState.validateCurrentPassword()
                    }
                }
            }
        }
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your password has been changed successfully.")
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
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    private func changePassword() async {
        formState.validateAll()
        guard formState.isValid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.changePassword(
                currentPassword: formState.currentPassword,
                newPassword: formState.newPassword
            )
            showSuccess = true
        } catch let error as NetworkError {
            switch error {
            case .clientError(_, _, _, let data):
                if let data = data,
                   let response = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    errorMessage = response.message
                } else {
                    errorMessage = error.localizedDescription
                }
            case .unauthorized:
                formState.fieldErrors["currentPassword"] = "Current password is incorrect"
                errorMessage = error.localizedDescription
            case .badRequest(let description):
                errorMessage = description
            default:
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
