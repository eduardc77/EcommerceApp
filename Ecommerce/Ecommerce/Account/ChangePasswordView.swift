import SwiftUI
import Networking

struct ChangePasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var error: Error?
    @State private var showError = false
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            Text("Enter your current password, then choose a secure password you can remember.")
                .listRowInsets(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                .multilineTextAlignment(.center)
                .listRowBackground(Color.clear)
            
            Section {
                SecureField("Current Password", text: $currentPassword)
                    .textContentType(.password)
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword)
                SecureField("Retype Password", text: $confirmPassword)
                    .textContentType(.newPassword)
            } footer: {
                PasswordRequirementsFooter(password: newPassword)
            }
            
            Section {
                AsyncButton("Change Password") {
                    await changePassword()
                }
                .disabled(isLoading || currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty || newPassword != confirmPassword)
            }
        }
        .contentMargins(.top, 16, for: .scrollContent)
        .listSectionSpacing(20)
        .navigationTitle("Change Password")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            if let error = error {
                Text(error.localizedDescription)
            }
        }
    }
    
    @MainActor
    private func changePassword() async {
        guard newPassword == confirmPassword else {
            error = NSError(
                domain: "ChangePasswordError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "New passwords do not match"]
            )
            showError = true
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
        } catch let networkError as NetworkError {
            error = handleNetworkError(networkError)
            showError = true
        } catch {
            self.error = NSError(
                domain: "ChangePasswordError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."]
            )
            showError = true
        }
    }
    
    private func handleNetworkError(_ error: NetworkError) -> Error {
        switch error {
        case .unauthorized:
            return NSError(
                domain: "ChangePasswordError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Current password is incorrect"]
            )
        case .badRequest(let description):
            // Server already provides user-friendly messages, use them directly
            return NSError(
                domain: "ChangePasswordError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: description.isEmpty ? "Invalid request. Please check your input and try again." : description]
            )
        case .clientError(let statusCode, _, _, let data):
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                // Use server's message directly - it's already user-friendly
                return NSError(
                    domain: "ChangePasswordError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            return NSError(
                domain: "ChangePasswordError",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "An error occurred while changing your password. Please try again."]
            )
        default:
            return NSError(
                domain: "ChangePasswordError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
            )
        }
    }
}
