import SwiftUI

struct RecoveryCodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var formState = RecoveryCodeFormState()
    @State private var isLoading = false
    
    let stateToken: String
    
    private enum Field {
        case recoveryCode
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationStack {
            Form {
                Text("Please enter one of your valid recovery codes to continue.")
                    .foregroundStyle(.secondary)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                
                Section {
                    ValidatedFormField(
                        title: "Recovery Code",
                        text: $formState.recoveryCode,
                        field: Field.recoveryCode,
                        focusedField: $focusedField,
                        error: recoveryCodeError,
                        validate: { formState.validateCode() },
                        capitalization: .never
                    )
                    .onChange(of: formState.recoveryCode) { _, newValue in
                        formState.recoveryCode = formState.formattedCode
                        formState.validateCode()
                        if formState.error != nil {
                            formState.error = nil
                            formState.showError = false
                        }
                    }
                }
                
                AsyncButton("Verify") {
                    await verifyCode()
                }
                .buttonStyle(.bordered)
                .disabled(!formState.isValidFormat || isLoading)
                .listRowInsets(.init())
                .listRowBackground(Color.clear)
            }
            .listSectionSpacing(.compact)
            .navigationTitle("Enter Recovery Code")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var recoveryCodeError: String? {
        if let validationError = formState.fieldErrors["recoveryCode"] {
            return validationError
        } else if let error = formState.error as? LocalizedError, let desc = error.errorDescription {
            return desc
        } else if let error = formState.error {
            return error.localizedDescription
        } else {
            return nil
        }
    }
    
    private func verifyCode() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await authManager.recoveryCodesManager.verifyCode(
                code: formState.recoveryCode.replacingOccurrences(of: "-", with: ""),
                stateToken: stateToken
            )
            await authManager.completeSignIn(response: response)
            dismiss()
        } catch {
            formState.setError(error)
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
    
    let totpService = PreviewTOTPService()
    let totpManager = TOTPManager(totpService: totpService)
    let emailVerificationService = PreviewEmailVerificationService()
    let emailVerificationManager = EmailVerificationManager(emailVerificationService: emailVerificationService)
    let recoeryCodesService = PreviewRecoveryCodesService()
    let recoveryCodesManager = RecoveryCodesManager(recoveryCodesService: recoeryCodesService)
    
    let authManager = AuthManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        recoveryCodesManager: recoveryCodesManager,
        authorizationManager: authorizationManager
    )
    
    RecoveryCodeEntryView(stateToken: "preview-token")
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif

// String extension for regex matching
extension String {
    func matches(_ regex: String) -> Bool {
        return self.range(of: regex, options: .regularExpression) != nil
    }
}
