import SwiftUI
import Networking

struct UserDetailView: View {
    let user: UserResponse
    let canEdit: Bool
    let namespace: Namespace.ID
    
    @Environment(UserManager.self) private var userManager
    @Environment(PermissionManager.self) private var permissionManager
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var editedDisplayName = ""
    @State private var editedEmail = ""
    @State private var selectedRole: Role?
    @State private var emailError: String?
    @State private var isCheckingEmail = false
    
    private var isEmailValid: Bool {
        editedEmail.contains("@") && editedEmail.contains(".")
    }
    
    private var canSave: Bool {
        !editedDisplayName.isEmpty && 
        isEmailValid &&
        !isCheckingEmail && 
        emailError == nil &&
        (editedEmail != user.email || editedDisplayName != user.displayName)
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    AsyncImage(url: URL(string: user.avatar ?? "")) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                            .frame(width: 100, height: 100)
                    }
                    .clipShape(Circle())
                    Spacer()
                }
                .padding(.vertical)
                
                if isEditing {
                    TextField("Display Name", text: $editedDisplayName)
                        .textInputAutocapitalization(.words)
                    
                    VStack(alignment: .leading) {
                        TextField("Email", text: $editedEmail)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .onChange(of: editedEmail) {
                                emailError = nil
                                if isEmailValid && editedEmail != user.email {
                                    checkEmailAvailability()
                                }
                            }
                        
                        if isCheckingEmail {
                            ProgressView()
                                .controlSize(.small)
                        } else if let error = emailError {
                            Text(error)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }
                } else {
                    LabeledContent("Username", value: user.username)
                    LabeledContent("Name", value: user.displayName)
                    LabeledContent("Email", value: user.email)
                    LabeledContent("Role", value: user.role.rawValue.capitalized)
                }
            }
            
            Section("Account Details") {
                LabeledContent("User ID", value: user.id)
                LabeledContent("Created", value: user.createdAt.formattedAsDate())
                LabeledContent("Updated", value: user.updatedAt.formattedAsDate())
            }
            
            if permissionManager.hasPermission(.manageRoles) {
                Section("Role") {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(Role.allCases, id: \.self) { role in
                            Text(role.rawValue.capitalized)
                                .tag(Optional(role))
                        }
                    }
                    .disabled(!isEditing)
                }
            }
        }
        .navigationTitle(isEditing ? "Edit User" : "User Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationTransition(.zoom(sourceID: user.id, in: namespace))
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        if isEditing {
                            Task {
                                await updateUser()
                            }
                        }
                        withAnimation {
                            isEditing.toggle()
                        }
                    }
                    .disabled(isEditing && !canSave)
                }
            }
            
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        withAnimation {
                            isEditing = false
                            editedDisplayName = user.displayName
                            editedEmail = user.email
                        }
                    }
                }
            }
        }
        .onAppear {
            editedDisplayName = user.displayName
            editedEmail = user.email
            selectedRole = user.role
        }
        .transitionSource(id: user.id, namespace: namespace)
    }
    
    @MainActor
    private func checkEmailAvailability() {
        guard editedEmail != user.email else { return }
        
        isCheckingEmail = true
        emailError = nil
        
        Task {
            let isAvailable = await userManager.checkEmailAvailability(editedEmail)
            if !isAvailable {
                emailError = "Email is already taken"
            }
            isCheckingEmail = false
        }
    }
    
    private func updateUser() async {
        await userManager.updateUser(
            id: user.id,
            displayName: editedDisplayName
        )
        isEditing = false
        dismiss()
    }
} 
