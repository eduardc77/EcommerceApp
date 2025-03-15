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
                    // Profile Section
                    Section {
                        VStack(spacing: 16) {
                            // Profile Image
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
                            
                            // User Info
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
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowBackground(Color.clear)
                    }
                    
                    // Account Information
                    Section {
                        if isEditing {
                            TextField("Email", text: $editedEmail)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        } else {
                            LabeledContent("Email", value: user.email)
                        }
                        LabeledContent("Username", value: user.username)
                    } header: {
                        Text("Account Information")
                    }
                    
                    // Email Verification Section
                    if authManager.requiresEmailVerification {
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
                    
                    // Sign Out Section
                    Section {
                        Button(role: .destructive) {
                            Task {
                                await authManager.signOut()
                            }
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }
                } else {
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
            .toolbar {
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
            .onChange(of: authManager.currentUser) { oldValue, newValue in
                // Update editing fields if user data changes
                if let user = newValue, !isEditing {
                    editedName = user.displayName
                    editedEmail = user.email
                }
            }
            .task {
                await authManager.refreshProfile()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
            .environment(AuthenticationManager(
                authService: PreviewAuthenticationService(),
                userService: PreviewUserService(),
                tokenStore: PreviewTokenStore(),
                totpService: PreviewTOTPService(),
                emailVerificationService: PreviewEmailVerificationService()
            ))
    }
} 
