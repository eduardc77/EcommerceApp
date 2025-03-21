import SwiftUI

struct TOTPSetupView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = SetupStep.intro
    @State private var qrCode: String?
    @State private var secret: String?
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var isLoading = false
    @State private var showVerification = false
    
    private enum SetupStep {
        case intro
        case qrCode
    }
    
    var body: some View {
        NavigationStack {
            Form {
                switch currentStep {
                case .intro:
                    introSection
                case .qrCode:
                    if let qrCode = qrCode, let secret = secret {
                        qrCodeSection(qrCode: qrCode, secret: secret)
                    }
                }
            }
            .navigationTitle("Set Up Two-Factor")
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
            .alert("Setup Failed", isPresented: .init(
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
            .task {
                // Start setup process when view appears
                if currentStep == .intro {
                    await startSetup()
                }
            }
            .sheet(isPresented: $showVerification) {
                VerificationView(type: .setupTOTP)
            }
        }
    }
    
    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("Two-factor authentication adds an extra layer of security to your account by requiring both your password and a verification code from an authenticator app.")
                    .font(.body)
                
                Text("You'll need an authenticator app like Google Authenticator, Authy, or 1Password to complete setup.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                Button {
                    withAnimation {
                        currentStep = .qrCode
                    }
                } label: {
                    Text("Begin Setup")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func qrCodeSection(qrCode: String, secret: String) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                Text("1. Open your authenticator app")
                    .font(.headline)
                
                Text("2. Scan this QR code or manually enter the setup key")
                    .font(.headline)
                
                QRCodeView(url: qrCode, size: 200)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Divider()
                
                Text("Setup Key")
                    .font(.headline)
                
                Text(secret)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                Text("3. Tap Continue when you're ready to verify")
                    .font(.headline)
                
                Button {
                    showVerification = true
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
        } footer: {
            Text("Keep your setup key in a safe place. You'll need it if you want to set up two-factor authentication on another device.")
        }
    }
    
    private func startSetup() async {
        isLoading = true
        do {
            let setupData = try await authManager.totpManager.setupTOTP()
            qrCode = setupData.qrCode
            secret = setupData.secret
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
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
    
    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        authorizationManager: authorizationManager
    )
    
    TOTPSetupView()
        .environment(authManager)
}
#endif
