import SwiftUI
import Networking
import PhotosUI

struct AccountView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(RecoveryCodesManager.self) private var recoveryCodesManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var editedEmail = ""
    @State private var isRefreshing = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var disableAction: DisableAction?
    @State private var enableAction: EnableAction?
    @State private var password = ""
    @State private var showPasswordPrompt = false
    @State private var disableError: Error?
    @State private var showingError = false
    @State private var showDisableAlert = false
    @State private var onAppearRefreshed = false

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
        // Social auth users have their email verified by default
        // and don't have password authentication
        return user.emailVerified && !user.hasPasswordAuth
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = user {
                    profileSection(user)
                    accountInformationSection(user)
                    if !isSocialAuthUser {
                        twoFactorSection
                    }
                    signOutSection
                } else {
                    noProfileView
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await authManager.refreshProfile()
            }
            .task {
                await loadProfileIfNeeded()
            }
            .sheet(item: $enableAction) { action in
                switch action {
                case .emailVerification:
                    VerificationView(type: .initialEmailFromAccountSettings(email: user?.email ?? ""))
                case .emailMFA:
                    VerificationView(type: .enableEmailMFA(email: user?.email ?? ""))
                case .totp:
                    TOTPSetupView()
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
                Text("This will remove an important security feature from your account. You'll need to verify your identity to continue.")
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
            .toolbar {
                AccountToolbarContent(
                    user: user,
                    isEditing: $isEditing,
                    editedName: $editedName,
                    editedEmail: $editedEmail,
                    authManager: authManager
                )

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authManager.currentUser) { oldValue, newValue in
                updateEditingFields(user: newValue)
            }
            .onChange(of: emailVerificationManager.requiresEmailVerification) { _, requiresEmailVerification in
                if !requiresEmailVerification {
                    enableAction = nil
                }
            }
            .onChange(of: selectedItem) { _, item in
                handleProfilePhotoSelection(item)
            }
            .navigationDestination(for: String.self) { route in
                switch route {
                case "signup":
                    SignUpView()
                case "forgot-password":
                    Text("")
                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: - Sections

    private func profileSection(_ user: UserResponse) -> some View {
        Section {
            VStack(spacing: 10) {
                profileImage(user)
                userInfo(user)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func accountInformationSection(_ user: UserResponse) -> some View {
        Section {
            if isEditing {
                editableAccountInfo
            } else {
                accountInfo(user)
            }
        } header: {
            Text("Account Information")
        }
    }

    private var twoFactorSection: some View {
        Section {
            if let currentUser = authManager.currentUser {
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
                } else if !isSocialAuthUser {
                    // Show TOTP and Email MFA options only for non-social auth users
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
                                Label("Enable Authenticator", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(role: .destructive) {
                                disableAction = .totp
                                showDisableAlert = true
                            } label: {
                                Label("Disable Authenticator", systemImage: "minus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 8)

                    // Email MFA Cell
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "shield.righthalf.filled")
                                .font(.title)
                                .foregroundStyle(emailVerificationManager.isEmailMFAEnabled ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email MFA")
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
                                Label("Enable Email MFA", systemImage: "plus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button(role: .destructive) {
                                disableAction = .email
                                showDisableAlert = true
                            } label: {
                                Label("Disable Email MFA", systemImage: "minus.circle.fill")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 8)

                    // Recovery Codes Cell
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "key.fill")
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
            }
        } header: {
            Text("Two-Factor Authentication")
        } footer: {
            if let currentUser = authManager.currentUser,
               !isSocialAuthUser && // Only show recommendation for non-social auth users
               currentUser.emailVerified && 
               !authManager.totpManager.isTOTPMFAEnabled && 
               !emailVerificationManager.isEmailMFAEnabled {
                Text("We recommend enabling at least one form of two-factor authentication to better protect your account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var signOutSection: some View {
        Section {
            AsyncButton(role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Components

    private func profileImage(_ user: UserResponse) -> some View {
        Group {
            if let pictureURL = URL(string: user.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png") {
                AsyncImage(url: pictureURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
                    .frame(width: 80, height: 80)
            }
        }
        .overlay(alignment: .bottom) {
            if isEditing {
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Text("Edit")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .offset(y: 8)
            }
        }
    }

    private func userInfo(_ user: UserResponse) -> some View {
        VStack(spacing: 4) {
            if isEditing {
                TextField("Name", text: $editedName)
                    .textContentType(.name)
                    .multilineTextAlignment(.center)
                    .font(.headline.bold())
            } else {
                Text(user.displayName)
                    .font(.headline.bold())
            }

            Text("Joined \(user.createdAt?.formattedAsDate() ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var editableAccountInfo: some View {
        TextField("Email", text: $editedEmail)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
    }

    private func accountInfo(_ user: UserResponse) -> some View {
        Group {
            LabeledContent("Email", value: user.email)
            LabeledContent("Username", value: user.username)
        }
    }

    private var noProfileView: some View {
        ContentUnavailableView {
            Label("No Profile", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text("Unable to load profile information")
        } actions: {
            Button("Retry") {
                Task {
                    await authManager.refreshProfile()
                }
            }
        }
    }

    // MARK: - Toolbar

    private struct AccountToolbarContent: ToolbarContent {
        let user: UserResponse?
        @Binding var isEditing: Bool
        @Binding var editedName: String
        @Binding var editedEmail: String
        let authManager: AuthenticationManager

        var body: some ToolbarContent {
            if user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    AsyncButton(isEditing ? "Done" : "Edit") {
                        withAnimation {
                            if isEditing {
                                // Save changes
                                Task {
                                    await authManager.updateProfile(
                                        displayName: editedName,
                                        email: editedEmail
                                    )
                                }
                            } else {
                                // Start editing
                                editedName = user?.displayName ?? ""
                                editedEmail = user?.email ?? ""
                            }
                            isEditing.toggle()
                        }
                    }
                }

                if isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            withAnimation {
                                isEditing = false
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func loadProfileIfNeeded() async {
        if authManager.currentUser == nil || !onAppearRefreshed {
            await authManager.refreshProfile()
            onAppearRefreshed = true
        }
    }
    
    private func handleProfilePhotoSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self) {
                // Here you would typically upload the image data and get back a URL
                // For now, we'll just use the default avatar
                _ = await authManager.updateProfile(
                    displayName: user?.displayName ?? "",
                    profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
                )
            }
        }
    }

    private func updateEditingFields(user: UserResponse?) {
        if let user = user, !isEditing {
            editedName = user.displayName
            editedEmail = user.email
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
    let emailVerificationManager = EmailVerificationManager(emailVerificationService:emailVerificationService)
    let recoeryCodesService = PreviewRecoveryCodesService()
    let recoveryCodesManager = RecoveryCodesManager(recoveryCodesService: recoeryCodesService)

    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        recoveryCodesManager: recoveryCodesManager,
        authorizationManager: authorizationManager
    )

    NavigationStack {
        AccountView()
            .environment(authManager)
            .environment(emailVerificationManager)
            .environment(totpManager)
            .environment(recoveryCodesManager)
    }
}
#endif
