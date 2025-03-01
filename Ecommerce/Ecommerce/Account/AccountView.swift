import SwiftUI
import Networking

struct AccountView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var editedEmail = ""
    @State private var isRefreshing = false
    
    var body: some View {
        List {
            if authManager.isLoading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            } else if let user = authManager.currentUser {
                Section {
                    HStack(spacing: 16) {
                        Group {
                            if let avatarURL = URL(string: user.avatar) {
                                AsyncImage(url: avatarURL) { image in
                                    image
                                        .resizable()
                                        .frame(width: 80, height: 80)
                                        .scaledToFit()
                                } placeholder: {
                                    ProgressView()
                                }
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.secondary)
                                    .frame(width: 80, height: 80)
                            }
                        }
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .fill(.secondary.opacity(0.2))
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            if isEditing {
                                TextField("Name", text: $editedName)
                                    .font(.headline)
                                    .textContentType(.name)
//                                TextField("Email", text: $editedEmail)
//                                    .font(.subheadline)
//                                    .textContentType(.emailAddress)
//                                    .keyboardType(.emailAddress)
                            } else {
                                Text(user.displayName)
                                    .font(.headline)
                                Text(user.username)
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Profile")
                } footer: {
                    if isEditing {
                        Text("Update your profile information")
                    } else {
                        Text("Joined \(user.createdAt.formattedAsDate())")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section {
                    Button(role: .destructive, action: signOut) {
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
        .overlay {
            if authManager.isLoading {
                ProgressView()
            }
        }
        .refreshable {
            await authManager.refreshProfile()
        }
        .toolbar {
            if let user = authManager.currentUser {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            Task {
                                await updateProfile()
                                withAnimation {
                                    isEditing = false
                                }
                            }
                        } else {
                            startEditing(user: user)
                            withAnimation {
                                isEditing = true
                            }
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
    }
    
    private func startEditing(user: UserResponse) {
        editedName = user.displayName
        editedEmail = user.email
    }
    
    private func updateProfile() async {
        await authManager.updateProfile(
            displayName: editedName
        )
    }
    
    private func signOut() {
        Task {
            await authManager.signOut()
        }
    }
}

#Preview {
    NavigationStack {
        AccountView()
            .environment(AuthenticationManager(
                authService: PreviewAuthenticationService(),
                userService: PreviewUserService(),
                tokenStore: PreviewTokenStore()
            ))
    }
} 
