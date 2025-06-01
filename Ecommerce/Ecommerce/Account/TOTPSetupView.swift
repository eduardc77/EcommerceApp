import SwiftUI

struct TOTPSetupView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var qrCode: String?
    @State private var secret: String?
    @State private var error: Error?
    @State private var isLoading = false
    @State private var showVerification = false
    @State private var showManualEntry = false
    
    var body: some View {
        Form {
            Section {
                InfoHeaderView(
                    systemIcon: "qrcode.viewfinder",
                    title: "Setup Authenticator",
                    description: Text("Open your authenticator app and scan the QR code below to add your account.")
                )
                .padding(.top)
                
                if let qrCode = qrCode {
                    QRCodeView(url: qrCode, size: 180)
                }
            }
            .frame(maxWidth: .infinity)
            
            if let secret = secret {
                Section {
                    DisclosureGroup("Enter Setup Key Manually", isExpanded: $showManualEntry) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(formatSetupKey(secret))
                                .font(.system(.footnote, design: .monospaced))
                                .fontWeight(.semibold)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .textSelection(.enabled)
                            
                            Button {
                                UIPasteboard.general.string = secret
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Setup Key")
                                }
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                            }
                            .padding(.top, 4)
                        }
                    }
                } footer: {
                    if showManualEntry {
                        Text("If you can't scan the QR code, you can manually enter this setup key in your authenticator app.")
                    }
                }
            }
        }
        .contentMargins(.top, 16, for: .scrollContent)
        .listSectionSpacing(20)
        .navigationTitle("Setup Authenticator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Next") {
                    showVerification = true
                }
                .fontWeight(.medium)
            }
        }
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .task {
            await startSetup()
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
        .sheet(isPresented: $showVerification) {
            VerificationView(type: .enableTOTP)
        }
    }
    
    private func formatSetupKey(_ key: String) -> String {
        let chunks = key.chunked(into: 4)
        return chunks.joined(separator: "-")
    }
    
    private func startSetup() async {
        isLoading = true
        do {
            let setupData = try await authManager.totpManager.enableTOTP()
            qrCode = setupData.qrCode
            secret = setupData.secret
            isLoading = false
        } catch {
            self.error = error
            isLoading = false
        }
    }
}

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
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
    
    TOTPSetupView()
        .environment(authManager)
}
#endif
