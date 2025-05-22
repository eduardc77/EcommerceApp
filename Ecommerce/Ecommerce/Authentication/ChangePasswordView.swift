import SwiftUI
import Networking

struct ChangePasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            } footer: {
                Text("Your password must be at least 8 characters long, include a number, an uppercase letter, a lowercase letter, and a special character.")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }
            
            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
            
            Section {
                AsyncButton("Change Password") {
                    await changePassword()
                }
                .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
            }
        }
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
    
    @MainActor
    private func changePassword() async {
        guard newPassword == confirmPassword else {
            errorMessage = "New passwords do not match"
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.changePassword(
                currentPassword: currentPassword,
                newPassword: newPassword
            )
            dismiss()
        } catch let error as NetworkError {
            switch error {
            case .unauthorized:
                errorMessage = "Current password is incorrect"
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
