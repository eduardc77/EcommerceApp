import SwiftUI
import Networking
import PhotosUI

struct AccountView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var editedEmail = ""
    @State private var isRefreshing = false
    @State private var showingEmailVerification = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showingTOTPSetup = false
    @State private var showingDisableTOTPConfirmation = false
    @State private var showingDisableTOTPVerification = false
    @State private var disableTOTPCode = ""
    @State private var disableTOTPError: Error?
    @State private var showingDisableEmail2FAConfirmation = false
    @State private var showingDisableEmail2FAVerification = false
    @State private var disableEmail2FACode = ""
    @State private var disableEmail2FAError: Error?
    @State private var showingEnableEmail2FAVerification = false

    private var user: UserResponse? {
        authManager.currentUser
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = user {
                    profileSection(user)
                    accountInformationSection(user)
                    twoFactorSection
                    signOutSection
                } else {
                    noProfileView
                }
            }
            .navigationTitle("Account")
            .refreshable {
                await authManager.refreshProfile()
            }
            .sheet(isPresented: $showingEmailVerification) {
                EmailVerificationView(source: .account)
                    .interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingTOTPSetup) {
                TOTPSetupView()
            }
            .alert("Disable Two-Factor Authentication", isPresented: $showingDisableTOTPConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    showingDisableTOTPVerification = true
                }
            } message: {
                Text("This will remove an important security feature from your account. You'll need to verify your identity to continue.")
            }
            .sheet(isPresented: $showingDisableTOTPVerification) {
                TOTPDisableView()
            }
            .alert("Disable Email Verification", isPresented: $showingDisableEmail2FAConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Continue", role: .destructive) {
                    Task {
                        await handleDisableEmail2FA()
                    }
                }
            } message: {
                Text("This will remove email verification as a security feature from your account. You'll need to verify your identity to continue.")
            }
            .sheet(isPresented: $showingDisableEmail2FAVerification) {
                EmailVerificationDisableView()
            }
            .sheet(isPresented: $showingEnableEmail2FAVerification) {
                EmailVerificationSetupView()
            }
            .onChange(of: emailVerificationManager.requiresEmailVerification) { _, requiresEmailVerification in
                if !requiresEmailVerification {
                    showingEmailVerification = false
                }
            }
            .onChange(of: selectedItem) { _, item in
                handleProfilePhotoSelection(item)
            }
            .toolbar {
                AccountToolbarContent(
                    user: user,
                    isEditing: $isEditing,
                    editedName: $editedName,
                    editedEmail: $editedEmail,
                    authManager: authManager
                )
            }
            .onChange(of: authManager.currentUser) { oldValue, newValue in
                updateEditingFields(user: newValue)
            }
            .task {
                await authManager.refreshProfile()
                try? await emailVerificationManager.get2FAStatus()
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
            if emailVerificationManager.requiresEmailVerification {
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
                        showingEmailVerification = true
                    } label: {
                        Text("Verify Email")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 8)
            } else {
                // Show TOTP and Email 2FA options when email is verified
                // TOTP Cell
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(authManager.totpManager.isEnabled ? .green : .secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Authenticator App")
                                .font(.headline)
                            Text(authManager.totpManager.isEnabled ? "Enabled" : "Not enabled")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !authManager.totpManager.isEnabled {
                        Text("Use an authenticator app to generate verification codes for additional security.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            showingTOTPSetup = true
                        } label: {
                            Label("Enable Authenticator", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(role: .destructive) {
                            showingDisableTOTPConfirmation = true
                        } label: {
                            Label("Disable Authenticator", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)

                // Email 2FA Cell
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.badge.shield.half.filled.fill")
                            .font(.title2)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(emailVerificationManager.is2FAEnabled ? .green : .secondary)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Email Verification")
                                .font(.headline)
                            Text(emailVerificationManager.is2FAEnabled ? "Enabled" : "Not enabled")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if !emailVerificationManager.is2FAEnabled {
                        Text("Receive a verification code by email when signing in from a new device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Button {
                            showingEnableEmail2FAVerification = true
                        } label: {
                            Label("Enable Email Verification", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(role: .destructive) {
                            showingDisableEmail2FAConfirmation = true
                        } label: {
                            Label("Disable Email Verification", systemImage: "minus.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text("Two-Factor Authentication")
        } footer: {
            if !emailVerificationManager.requiresEmailVerification && 
               !authManager.totpManager.isEnabled && 
               !emailVerificationManager.is2FAEnabled {
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

            Text("Joined \(user.createdAt.formattedAsDate())")
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

    // MARK: - Event Handlers

    private func handleDisableEmail2FA() async {
        do {
            try await emailVerificationManager.setup2FA()
            showingDisableEmail2FAVerification = true
        } catch {
            // Handle error
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

    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        authorizationManager: authorizationManager
    )

    NavigationStack {
        AccountView()
            .environment(authManager)
            .environment(emailVerificationManager)
            .environment(totpManager)
    }
}
#endif
