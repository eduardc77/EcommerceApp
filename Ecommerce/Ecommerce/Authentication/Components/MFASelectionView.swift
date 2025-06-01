import SwiftUI

struct MFASelectionView: View {
    let stateToken: String
    let onSelect: (MFAOption) -> Void
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    InfoHeaderView(
                        systemIcon: "lock.square.stack.fill",
                        title: "Select Verification Method",
                        description: Text("How would you like to verify your identity?")
                    )
                    .padding(.vertical)
                    
                    ForEach(authManager.availableMFAMethods.compactMap { method in
                        switch method {
                        case .totp: return MFAOption.totp
                        case .email: return MFAOption.email
                        case .recoveryCode: return nil // Don't show recovery code in main list
                        }
                    }, id: \.self) { option in
                        Button {
                            Task {
                                await selectMethod(option)
                            }
                        } label: {
                            HStack {
                                Image(systemName: option.icon)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 32)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    
                                    Text(option.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                }
                
                // Recovery option section
                Section {
                    Button {
                        Task {
                            await selectMethod(.recoveryCode)
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Can't Access Your Authenticator?")
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                                Text("Use a recovery code to sign in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
            .contentMargins(.top, 16, for: .scrollContent)
            .listSectionSpacing(20)
            .navigationTitle("Verification Method")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") {
                    error = nil
                }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private func selectMethod(_ option: MFAOption) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if case .recoveryCode = option {
                // For recovery codes, skip MFA selection and go straight to verification
                dismiss()
                onSelect(option)
            } else {
                // For other methods, use the MFA selection endpoint
                try await authManager.selectMFAMethod(method: option.method, stateToken: stateToken)
                dismiss()
                onSelect(option)
            }
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
    let recoveryCodesService = PreviewRecoveryCodesService()
    let recoveryCodesManager = RecoveryCodesManager(recoveryCodesService: recoveryCodesService)

    let authService = PreviewAuthenticationService(authorizationManager: authorizationManager)
    let authManager = AuthManager(
        authService: authService,
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        recoveryCodesManager: recoveryCodesManager,
        authorizationManager: authorizationManager
    )

    MFASelectionView(stateToken: "preview-token") { option in
        print("Selected option: \(option)")
    }
    .environment(authManager)
    .environment(emailVerificationManager)
    .environment(totpManager)
}
#endif 
