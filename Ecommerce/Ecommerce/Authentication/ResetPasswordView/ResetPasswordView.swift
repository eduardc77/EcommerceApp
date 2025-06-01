import SwiftUI
import Networking

// Add ErrorResponse struct for parsing backend errors
private struct ErrorResponse: Codable {
    let message: String
    let success: Bool
}

struct ResetPasswordView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    @State private var formState = ResetPasswordFormState()
    @FocusState private var focusedField: ResetPasswordField?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    @Environment(\.dismiss) private var dismiss
    let email: String
    
    init(email: String) {
        self.email = email
        _formState = State(initialValue: {
            let state = ResetPasswordFormState()
            state.isChangePassword = false
            return state
        }())
    }
    
    var body: some View {
        Form {
            Text("Enter the verification code sent to your email and choose a new password.")
                .listRowInsets(.init(top: 0, leading: 10, bottom: 0, trailing: 10))
                .multilineTextAlignment(.center)
                .listRowBackground(Color.clear)
            
            Section {
                ValidatedFormField(
                    title: "Verification Code",
                    text: $formState.code,
                    field: ResetPasswordField.code,
                    focusedField: $focusedField,
                    error: formState.fieldErrors["code"],
                    validate: { formState.validateCode() },
                    contentType: .oneTimeCode,
                    keyboardType: .numberPad,
                    capitalization: .never
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
                    title: "Retype Password",
                    text: $formState.confirmPassword,
                    field: ResetPasswordField.confirmPassword,
                    focusedField: $focusedField,
                    error: formState.fieldErrors["confirmPassword"],
                    validate: { formState.validateConfirmPassword() },
                    secureField: true
                )
            } footer: {
                PasswordRequirementsFooter(password: formState.newPassword)
            }
            
            Section {
                AsyncButton("Reset Password") {
                    await resetPassword()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .listRowInsets(.init())
            .listRowBackground(Color.clear)
        }
        .listSectionSpacing(20)
        .navigationTitle("Reset Password")
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
        .onDisappear {
            formState.reset()
            focusedField = nil
        }
    }
    
    private func resetPassword() async {
        formState.validateAll()
        guard formState.isValid else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await authManager.resetPassword(
                email: email,
                code: formState.code,
                newPassword: formState.newPassword
            )
            coordinator.popToRoot()
        } catch let error as NetworkError {
            self.error = handleNetworkError(error)
            showError = true
        } catch {
            self.error = NSError(
                domain: "ResetPasswordError",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."]
            )
            showError = true
        }
    }
    
    private func handleNetworkError(_ error: NetworkError) -> Error {
        switch error {
        case .badRequest(let description):
            // Server already provides user-friendly messages, use them directly
            return NSError(
                domain: "ResetPasswordError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: description.isEmpty ? "Invalid request. Please check your input and try again." : description]
            )
        case .clientError(let statusCode, _, _, let data):
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                // Use server's message directly - it's already user-friendly
                return NSError(
                    domain: "ResetPasswordError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            return interpretNetworkError(error)
        default:
            return interpretNetworkError(error)
        }
    }
    
    private func interpretNetworkError(_ error: NetworkError) -> Error {
        switch error {
        case .networkConnectionLost:
            return NSError(
                domain: "ResetPasswordError",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "Connection lost. Please check your internet connection and try again."]
            )
        case .cannotConnectToHost:
            return NSError(
                domain: "ResetPasswordError",
                code: -1004,
                userInfo: [NSLocalizedDescriptionKey: "Cannot connect to server. Please try again later."]
            )
        case .dnsLookupFailed:
            return NSError(
                domain: "ResetPasswordError",
                code: -1003,
                userInfo: [NSLocalizedDescriptionKey: "DNS lookup failed. Please check your internet connection."]
            )
        case .cannotFindHost:
            return NSError(
                domain: "ResetPasswordError",
                code: -1003,
                userInfo: [NSLocalizedDescriptionKey: "Cannot find server. Please try again later."]
            )
        case .timeout:
            return NSError(
                domain: "ResetPasswordError",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "The request timed out. Please try again."]
            )
        case .unauthorized(let description):
            return NSError(
                domain: "ResetPasswordError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: description.isEmpty ? "Your session has expired. Please try again." : description]
            )
        default:
            return NSError(
                domain: "ResetPasswordError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."]
            )
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ChangePasswordView()
            .environment(AuthManager(
                authService: PreviewAuthenticationService(),
                userService: PreviewUserService(),
                totpManager: TOTPManager(totpService: PreviewTOTPService()),
                emailVerificationManager: EmailVerificationManager(emailVerificationService: PreviewEmailVerificationService()),
                recoveryCodesManager: RecoveryCodesManager(recoveryCodesService: PreviewRecoveryCodesService()),
                authorizationManager: AuthorizationManager(
                    refreshClient: PreviewRefreshAPIClient(),
                    tokenStore: PreviewTokenStore()
                )
            ))
    }
}
#endif
