import SwiftUI

struct RecoveryCodeEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @State private var formState = RecoveryCodeFormState()
    @State private var isLoading = false
    
    let stateToken: String
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                            Text("Enter Recovery Code")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                Text("Please enter one of your valid recovery codes to continue.")
                                .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    
                TextField("Code", text: $formState.recoveryCode)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .onChange(of: formState.recoveryCode) { _, newValue in
                        formState.recoveryCode = formState.formattedCode
                        }
                
                if formState.showError {
                    Text(formState.error?.localizedDescription ?? "An error occurred")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button(action: {
                        Task {
                            await verifyCode()
                        }
                }) {
                        if isLoading {
                            ProgressView()
                        } else {
                        Text("Verify")
                                .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!formState.isValidFormat || isLoading)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
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
