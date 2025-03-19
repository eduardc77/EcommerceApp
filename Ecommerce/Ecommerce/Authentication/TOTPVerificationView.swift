import SwiftUI

struct TOTPVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    let tempToken: String
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var isLoading = false
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter the 6-digit verification code from your authenticator app")
                            .font(.headline)
                        
                        OneTimeCodeInput(code: $verificationCode, codeLength: 6)
                            .focused($isCodeFieldFocused)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        
                        AsyncButton {
                            await verify()
                        } label: {
                            Text("Verify")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(verificationCode.count != 6 || isLoading)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Two-Factor Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Verification Failed", isPresented: .init(
                get: { error != nil },
                set: { if !$0 { error = nil } }
            )) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error {
                    Text(error.localizedDescription)
                }
            }
            .onAppear {
                isCodeFieldFocused = true
            }
        }
    }
    
    private func verify() async {
        isLoading = true
        do {
            try await authManager.verifyTOTPForLogin(code: verificationCode, tempToken: tempToken)
            
            // Wait a moment for state to update before dismissing
            try? await Task.sleep(for: .milliseconds(100))
            
            await MainActor.run {
                // Only dismiss if we don't need email verification
                if !authManager.requires2FAEmailVerification {
                    dismiss()
                }
            }
        } catch {
            self.error = error
        }
        isLoading = false
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

    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        authorizationManager: authorizationManager
    )
    
    TOTPVerificationView(tempToken: "preview-token")
        .environment(authManager)
}
#endif
