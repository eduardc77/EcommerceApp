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
    
    private enum SetupStep {
        case intro
        case qrCode
        case verification
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
                case .verification:
                    verificationSection
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
                    withAnimation {
                        currentStep = .verification
                    }
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
    
    private var verificationSection: some View {
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
                    await verifyAndEnable()
                } label: {
                    Text("Verify and Enable")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(verificationCode.count != 6)
            }
            .padding(.vertical, 8)
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
    
    private func verifyAndEnable() async {
        isLoading = true
        do {
            try await authManager.totpManager.verifyAndEnableTOTP(code: verificationCode)
            dismiss() // Success, close the sheet
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
