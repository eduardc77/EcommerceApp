import SwiftUI

struct TOTPVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Enter the 6-digit verification code from your authenticator app")
                            .font(.headline)
                        
                        TextField("Verification Code", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(.title2, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .onChange(of: verificationCode) { oldValue, newValue in
                                // Limit to 6 digits
                                if newValue.count > 6 {
                                    verificationCode = String(newValue.prefix(6))
                                }
                                // Remove non-digits
                                verificationCode = newValue.filter { $0.isNumber }
                            }
                        
                        AsyncButton {
                            await verify()
                        } label: {
                            Text("Verify")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(verificationCode.count != 6)
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Two-Factor Authentication")
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
    
    private func verify() async {
        isLoading = true
        do {
            if authManager.requiresTOTPVerification {
                // We're verifying during login
                _ = try await authManager.verifyTOTPForLogin(code: verificationCode)
            } else {
                // We're verifying during normal TOTP operations
                try await authManager.totpManager.verifyTOTP(verificationCode)
            }
            dismiss() // Success, close the sheet
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
    
    TOTPVerificationView()
        .environment(authManager)
}
#endif
