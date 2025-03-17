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

    private var user: UserResponse? {
        authManager.currentUser
    }

    var body: some View {
        NavigationStack {
            Form {
                if let user = user {
                    profileSection(user)
                    accountInformationSection(user)

                    if emailVerificationManager.requiresEmailVerification {
                        emailVerificationSection
                    }
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

    private var emailVerificationSection: some View {
        Section {
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

                AsyncButton("Verify Email") {
                    showingEmailVerification = true
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 8)
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
                await authManager.updateProfile(
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

    NavigationStack {
        AccountView()
            .environment(authManager)
            .environment(emailVerificationManager)
            .environment(totpManager)
    }
}
#endif
