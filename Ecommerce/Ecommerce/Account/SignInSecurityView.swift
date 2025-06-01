import SwiftUI
import Networking

struct SignInSecurityView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(RecoveryCodesManager.self) private var recoveryCodesManager
    @State private var enableRecoveryCodes = false
    
    private var user: UserResponse? {
        authManager.currentUser
    }
    
    private var isSocialAuthUser: Bool {
        guard let user = user else { return false }
        return user.emailVerified && !user.hasPasswordAuth
    }
    
    var body: some View {
        Form {
            if let user = user {
                Section {
                    LabeledContent("Username", value: user.username)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Phone number", value: "+000 000 00")
                }
                header: {
                    Text("Sign-In Information")
                } footer: {
                    Text("The email address, phone number and username can be used to sign in, verify your identity and help recover your account.")
                }
                
                // Only show security section for non-social auth users
                if !isSocialAuthUser {
                    Section {
                        NavigationLink("Change Password") {
                            ChangePasswordView()
                        }
                        
                        // Navigation Link to Authentication Settings (MFA, Recovery Codes)
                        if user.emailVerified {
                            NavigationLink("Multifactor Authentication") {
                                AuthenticationSettingsView()
                            }
                        } else {
                            HStack {
                                Text("Multifactor Authentication")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }
                            .accessibilityLabel("Multifactor Authentication - Email verification required")
                        }
                    } header: {
                        Text("Security")
                    } footer: {
                        if !user.emailVerified {
                            Text("Email verification is required to access multifactor authentication settings.")
                        }
                    }
                }
                
                deleteAccountSection
            }
        }
        .navigationTitle("Sign-In & Security")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $enableRecoveryCodes) {
            RecoveryCodesView()
        }
    }
    
    private var deleteAccountSection: some View {
        Section {
            AsyncButton(role: .destructive, font: .body) {
                
            } label: {
                Text("Delete Account")
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
