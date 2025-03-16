import SwiftUI
import Networking
import PhotosUI

struct AccountView: View {
    @Environment(AuthenticationManager.self) private var authManager
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
            List {
                if let user = user {
                    profileSection(user)
                    accountInformationSection(user)
                    
                    if authManager.requiresEmailVerification {
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
            .onChange(of: authManager.requiresEmailVerification) { _, requiresEmailVerification in
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
            VStack(spacing: 16) {
                profileImage(user)
                userInfo(user)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
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
                
                Button("Verify Email") {
                    showingEmailVerification = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.vertical, 8)
        }
    }
    
    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                Task {
                    await authManager.signOut()
                }
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
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
                    .font(.title2.bold())
            } else {
                Text(user.displayName)
                    .font(.title2.bold())
            }
            
            Text("Joined \(user.createdAt.formattedAsDate())")
                .font(.subheadline)
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
                    Button(isEditing ? "Done" : "Edit") {
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

#Preview {
    // Create shared dependencies
    let tokenStore = PreviewTokenStore()
    let refreshClient = PreviewRefreshAPIClient()
    let authorizationManager = AuthorizationManager(
        refreshClient: refreshClient,
        tokenStore: tokenStore
    )

    NavigationStack {
        AccountView()
            .environment(AuthenticationManager(
                authService: PreviewAuthenticationService(),
                userService: PreviewUserService(),
                totpService: PreviewTOTPService(),
                emailVerificationService: PreviewEmailVerificationService(),
                authorizationManager: authorizationManager
            ))
    }
} 
