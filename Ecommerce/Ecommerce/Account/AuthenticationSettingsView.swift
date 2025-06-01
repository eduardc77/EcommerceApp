import SwiftUI
import Networking

struct AuthenticationSettingsView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(RecoveryCodesManager.self) private var recoveryCodesManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    
    // State variables for presenting sheets/alerts, moved from AccountView
    @State private var enableAction: EnableAction? = nil
    @State private var disableAction: DisableAction? = nil
    @State private var password = ""
    @State private var showPasswordPrompt = false
    @State private var disableError: Error? = nil
    @State private var showingError = false
    @State private var showDisableAlert = false
    
    private enum DisableAction: Identifiable {
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
            case .totp: return "Disable Authenticator"
            case .email: return "Disable Email MFA"
            }
        }
    }
    
    private enum EnableAction: Identifiable {
        case emailVerification
        case emailMFA
        case totp
        case recoveryCodes
        
        var id: String {
            switch self {
            case .emailVerification: return "email-verification"
            case .emailMFA: return "email-mfa"
            case .totp: return "totp"
            case .recoveryCodes: return "recovery-codes"
            }
        }
        
        var title: String {
            switch self {
            case .emailVerification: return "Verify Email"
            case .emailMFA: return "Enable Email MFA"
            case .totp: return "Enable Authenticator"
            case .recoveryCodes: return "Manage Recovery Codes"
            }
        }
        
        var icon: String {
            switch self {
            case .totp: return "plus.circle.fill"
            case .emailMFA: return "plus.circle.fill"
            case .emailVerification: return "checkmark.circle.fill"
            case .recoveryCodes: return "key.fill"
            }
        }
    }
    
    private var user: UserResponse? {
        authManager.currentUser
    }
    
    private var isSocialAuthUser: Bool {
        guard let user = user else { return false }
        return user.emailVerified && !user.hasPasswordAuth
    }
    
    var body: some View {
        Form {
            if let currentUser = user, !isSocialAuthUser {
                Section {
                    if !currentUser.emailVerified {
                        // Show only email verification cell if email is not verified
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.title2)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Email Not Verified")
                                        .font(.headline)
                                    Text("Verify your email to access all features")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Button {
                                enableAction = .emailVerification
                            } label: {
                                Text("Verify Email")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 8)
                    } else {
                        // Show TOTP and Email MFA options for non-social auth users only when email is verified
                        // TOTP Cell
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "lock.shield.fill")
                                    .font(.title)
                                    .foregroundStyle(authManager.totpManager.isTOTPMFAEnabled ? .green : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Authenticator App")
                                        .font(.headline)
                                    Text(authManager.totpManager.isTOTPMFAEnabled ? "Enabled" : "Not enabled")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if !authManager.totpManager.isTOTPMFAEnabled {
                                Text("Use an authenticator app to generate verification codes for additional security.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    enableAction = .totp
                                } label: {
                                    Label("Enable", systemImage: "plus.circle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(role: .destructive) {
                                    disableAction = .totp
                                    showDisableAlert = true
                                } label: {
                                    Label("Disable", systemImage: "minus.circle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Email MFA Cell
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "envelope.badge.shield.half.filled.fill")
                                    .font(.title)
                                    .foregroundStyle(emailVerificationManager.isEmailMFAEnabled ? .green : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Email Authentication")
                                        .font(.headline)
                                    Text(emailVerificationManager.isEmailMFAEnabled ? "Enabled" : "Not enabled")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            if !emailVerificationManager.isEmailMFAEnabled {
                                Text("Receive verification codes by email when signing in for additional security.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Button {
                                    enableAction = .emailMFA
                                } label: {
                                    Label("Enable", systemImage: "plus.circle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button(role: .destructive) {
                                    disableAction = .email
                                    showDisableAlert = true
                                } label: {
                                    Label("Disable", systemImage: "minus.circle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Recovery Codes Cell
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "key.2.on.ring.fill")
                                    .font(.title)
                                    .foregroundStyle(recoveryCodesManager.status?.enabled == true
                                                     ? (recoveryCodesManager.status?.hasValidCodes == true ? .green : .yellow)
                                                     : .secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Recovery Codes")
                                        .font(.headline)
                                    if recoveryCodesManager.status?.enabled == true {
                                        if recoveryCodesManager.status?.hasValidCodes == true {
                                            Text("Enabled")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Text("Action Required")
                                                .font(.subheadline)
                                                .foregroundStyle(.yellow)
                                        }
                                    } else {
                                        Text("Not enabled")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            if recoveryCodesManager.status?.enabled == true && recoveryCodesManager.status?.hasValidCodes == false {
                                Text("You need to generate recovery codes to ensure you don't get locked out of your account.")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            } else {
                                Text("Backup codes for when you can't access your MFA methods")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button {
                                enableAction = .recoveryCodes
                            } label: {
                                if recoveryCodesManager.status?.enabled == true && recoveryCodesManager.status?.hasValidCodes == false {
                                    Label("Generate Recovery Codes", systemImage: "exclamationmark.triangle.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Label("Manage Recovery Codes", systemImage: "key.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!authManager.totpManager.isTOTPMFAEnabled && !emailVerificationManager.isEmailMFAEnabled)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Multifactor Authentication")
                } footer: {
                    if !currentUser.emailVerified {
                        Text("Email verification is required to access multifactor authentication features.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !isSocialAuthUser &&
                        currentUser.emailVerified &&
                        !authManager.totpManager.isTOTPMFAEnabled &&
                        !emailVerificationManager.isEmailMFAEnabled {
                        Text("We recommend enabling at least one form of two-factor authentication to better protect your account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
            }
        }
        .listSectionSpacing(20)
        .navigationTitle("Authentication Settings")
        .task {
            // Refresh all MFA statuses
            await authManager.refreshMFAStatuses()
        }
        .sheet(item: $enableAction) { action in
            switch action {
            case .emailVerification:
                VerificationView(type: .initialEmailFromAccountSettings(email: user?.email ?? ""))
            case .emailMFA:
                VerificationView(type: .enableEmailMFA(email: user?.email ?? ""))
            case .totp:
                TOTPIntroView()
            case .recoveryCodes:
                RecoveryCodesView()
            }
        }
        .alert("Disable MFA", isPresented: $showDisableAlert) {
            Button("Cancel", role: .cancel) {
                disableAction = nil
            }
            Button("Continue", role: .destructive) {
                showPasswordPrompt = true
            }
        } message: {
            Text("This will remove an important security feature from your account. You\'ll need to verify your identity to continue.")
        }
        .alert("Enter Password", isPresented: $showPasswordPrompt) {
            SecureField("Password", text: $password)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {
                password = ""
                showPasswordPrompt = false
            }
            Button("Disable", role: .destructive) {
                handleDisableAction()
            }
        } message: {
            Text("Please enter your password to confirm this action.")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                disableError = nil
            }
        } message: {
            if let error = disableError {
                Text(error.localizedDescription)
            }
        }
    }
    
    private func handleDisableAction() {
        Task {
            do {
                switch disableAction {
                case .totp:
                    try await authManager.disableTOTP(password: password)
                    // Refresh profile after disabling
                    await authManager.refreshProfile()
                case .email:
                    try await authManager.disableEmailMFA(password: password)
                    // Refresh profile after disabling
                    await authManager.refreshProfile()
                case .none:
                    break
                }
                password = ""
                disableAction = nil
                showPasswordPrompt = false
            } catch {
                disableError = error
                showingError = true
            }
        }
    }
}
