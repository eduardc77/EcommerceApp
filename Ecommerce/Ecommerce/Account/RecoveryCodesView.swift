import SwiftUI

struct RecoveryCodesView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(RecoveryCodesManager.self) private var recoveryCodesManager
    @Environment(\.dismiss) private var dismiss
    
    let shouldLoadCodesOnAppear: Bool
    
    @State private var showError = false
    @State private var showPasswordPrompt = false
    @State private var password = ""
    @State private var error: Error?
    
    init(shouldLoadCodesOnAppear: Bool = true) {
        self.shouldLoadCodesOnAppear = shouldLoadCodesOnAppear
    }
    
    private var existingCodesSection: some View {
        Section {
            if recoveryCodesManager.codes.isEmpty {
                Text("You don't have any valid recovery codes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if recoveryCodesManager.codes.first?.code.contains("•") == true {
                Text("You have valid recovery codes, but they can only be viewed when generated. Generate new codes to view them.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recoveryCodesManager.codes, id: \.code) { code in
                    Text(code.code)
                        .font(.system(.body, design: .monospaced))
                }
                
                Button {
                    let allCodes = recoveryCodesManager.codes.map(\.code).joined(separator: "\n")
                    UIPasteboard.general.string = allCodes
                } label: {
                    HStack {
                        Text("Copy All Codes")
                        Spacer()
                        Image(systemName: "doc.on.doc")
                    }
                    .foregroundStyle(.tint)
                }
            }
        } footer: {
            Text("Each code can only be used once. Keep these codes in a safe place.")
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                existingCodesSection
            }
            .listSectionSpacing(20)
            .navigationTitle("Recovery Codes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if shouldLoadCodesOnAppear {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Generate") {
                            showPasswordPrompt = true
                        }
                    }
                }
            }
            .overlay {
                if recoveryCodesManager.isLoading {
                    ProgressView("Generating codes...")
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(8)
                }
            }
            .alert("Enter Password", isPresented: $showPasswordPrompt) {
                SecureField("Password", text: $password)
                Button("Generate", action: { Task { await generateNewCodes() } })
                Button("Cancel", role: .cancel) {
                    password = ""
                }
            } message: {
                Text("Please enter your password to generate new recovery codes. This will invalidate all existing codes.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .task {
                if shouldLoadCodesOnAppear {
                    await loadCodes()
                }
            }
        }
    }
    
    private func loadCodes() async {
        do {
            try await recoveryCodesManager.getCodes()
        } catch {
            self.error = error
            showError = true
        }
    }
    
    private func generateNewCodes() async {
        do {
            try await recoveryCodesManager.generateCodes(password: password)
            password = ""
            showPasswordPrompt = false
            // Don't call loadCodes() here since it will overwrite the actual codes with placeholders
        } catch {
            self.error = error
            showError = true
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
    
    RecoveryCodesView()
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
        .environment(recoveryCodesManager)
}
#endif
