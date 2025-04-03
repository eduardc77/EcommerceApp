import SwiftUI

struct MFASelectionView: View {
    let stateToken: String
    let onSelect: (MFAOption) -> Void
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    
    enum MFAOption: Identifiable {
        case totp
        case email
        
        var id: String {
            switch self {
            case .totp: return "totp"
            case .email: return "email"
            }
        }
        
        var title: String {
            switch self {
            case .totp: return "Authenticator App"
            case .email: return "Email"
            }
        }
        
        var subtitle: String {
            switch self {
            case .totp: return "Use your authenticator app to generate a code"
            case .email: return "Receive a verification code via email"
            }
        }
        
        var icon: String {
            switch self {
            case .totp: return "key.fill"
            case .email: return "envelope.fill"
            }
        }
        
        var method: MFAMethod {
            switch self {
            case .totp: return .totp
            case .email: return .email
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(authManager.availableMFAMethods.compactMap { method in
                        switch method {
                        case .totp: return MFAOption.totp
                        case .email: return MFAOption.email
                        }
                    }) { option in
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
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .disabled(isLoading)
                    }
                } header: {
                    Text("Choose Verification Method")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Select how you'd like to verify your identity")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Two-Factor Authentication")
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
            try await authManager.selectMFAMethod(method: option.method, stateToken: stateToken)
            onSelect(option)
            dismiss()
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

    let authService = PreviewAuthenticationService(authorizationManager: authorizationManager)
    let authManager = AuthenticationManager(
        authService: authService,
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
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
