import SwiftUI
import PhotosUI
import Networking

struct AccountView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(AuthenticationCoordinator.self) private var coordinator
    @Environment(\.dismiss) private var dismiss
    @State private var isRefreshing = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var onAppearRefreshed = false
    @State private var showPhotoPicker = false
    @State private var showEmailVerification = false
    
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
                    if !user.emailVerified {
                        verifyEmailWarningView
                    }
                    
                    Section {
                        NavigationLink(destination: PersonalInformationView()) {
                            Label("Personal Information", systemImage: "person.fill")
                        }
                        NavigationLink(destination: SignInSecurityView()) {
                            Label("Sign-In & Security", systemImage: "lock.shield.fill")
                        }
                        NavigationLink(destination: EmptyView()) { // Placeholder
                            Label("Payment & Shipping", systemImage: "creditcard.fill")
                        }
                    } header: {
                        profileSection(user)
                    }
                    .textCase(nil)
                    
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showEmailVerification) {
                VerificationView(type: .initialEmailFromAccountSettings(email: user?.email ?? ""))
            }
            .onChange(of: emailVerificationManager.requiresEmailVerification) { _, requiresEmailVerification in
                if !requiresEmailVerification {
                    showEmailVerification = false
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private func profileSection(_ user: UserResponse) -> some View {
        VStack {
            profileImage(user)
            userInfo(user)
        }
        .frame(maxWidth: .infinity)
        .textCase(nil)
        .foregroundStyle(.primary)
        .padding(.bottom, 30)
    }
    
    private var signOutSection: some View {
        Section {
            AsyncButton(role: .destructive, font: .body) {
                Task {
                    coordinator.popToRoot()
                    await authManager.signOut()
                }
            } label: {
                Text("Sign Out")
                    .frame(maxWidth: .infinity)
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
                .overlay(
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
                    .frame(width: 80, height: 80)
            }
        }
        .onTapGesture {
            showPhotoPicker = true
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
    }
    
    var verifyEmailWarningView: some View {
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
                showEmailVerification = true
            } label: {
                Text("Verify Email")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
    
    private func userInfo(_ user: UserResponse) -> some View {
        VStack(spacing: 4) {
            Text(user.displayName)
                .font(.title3)
                .fontWeight(.bold)
            
            Text("Joined \(user.createdAt?.formattedAsDate() ?? "")")
                .font(.caption)
                .foregroundStyle(.secondary)
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
    
    let authManager = AuthManager(
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
