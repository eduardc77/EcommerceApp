import SwiftUI
import PhotosUI
import Networking

struct PersonalInformationView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showPhotoPicker = false
    @State private var formState = PersonalInformationFormState()
    @State private var isDatePickerExpanded = false
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case displayName
    }

    // Computed property to check if there are unsaved changes
    private var hasUnsavedChanges: Bool {
        guard let user = authManager.currentUser else { return false }
        let trimmedName = formState.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let userGender = Gender(rawValue: user.gender ?? "") ?? .notSpecified
        
        return (!trimmedName.isEmpty && trimmedName != user.displayName) ||
               (formState.gender != userGender) ||
               (formState.dateOfBirth != user.dateOfBirthDate)
    }
    
    // Check if form can be submitted
    private var canSubmit: Bool {
        let trimmedName = formState.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && hasUnsavedChanges
    }

    // Helper to update editing fields when user data changes
    private func updateEditingFields(user: UserResponse?) {
        formState.initializeWith(user: user)
    }

    private var user: UserResponse? {
         authManager.currentUser
     }

    var body: some View {
        Form {
            if let user = user {
                Section {
                    // Name Field
                    LabeledContent("Name") {
                        TextField("Required", text: $formState.displayName)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .displayName)
                    }

                    // Date of Birth Field
                    Button(action: {
                        withAnimation {
                            isDatePickerExpanded.toggle()
                        }
                    }) {
                    LabeledContent("Date of Birth") {
                            Text(formState.dateOfBirth?.formatted(date: .abbreviated, time: .omitted) ?? "Not set")
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if isDatePickerExpanded {
                        DatePicker(
                            "Date of Birth",
                            selection: Binding(
                                get: { formState.dateOfBirth ?? Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date() },
                                set: {
                                    formState.dateOfBirth = $0
                                    formState.validateDateOfBirth()
                                }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                    }
                    
                    // Gender Field
                    Picker("Gender", selection: $formState.gender) {
                        ForEach(Gender.allCases, id: \.self) { gender in
                            Text(gender.displayName)
                                .tag(gender)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                    
                } header: {
                    VStack {
                        profilePhotoEditable(user: user)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom)
                }
            } else {
                 ContentUnavailableView {
                    Label("No Profile", systemImage: "person.crop.circle.badge.exclamationmark")
                } description: {
                    Text("Unable to load profile information")
                }
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .navigationTitle("Personal Information")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { oldValue, newValue in
            handleProfilePhotoSelection(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AsyncButton("Done") {
                    formState.validateAll()
                    if canSubmit {
                    Task {
                            let trimmedName = formState.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            let genderValue = formState.gender == .notSpecified ? nil : formState.gender.rawValue
                            
                        _ = await authManager.updateProfile(
                                displayName: trimmedName,
                                dateOfBirth: formState.dateOfBirth,
                                gender: genderValue
                        )
                        await authManager.refreshProfile()
                            dismiss()
                        }
                    }
                }
                .disabled(!canSubmit)
            }
        }
         .onAppear {
            updateEditingFields(user: user)
        }
        .onChange(of: user) { oldValue, newValue in
            updateEditingFields(user: newValue)
        }
    }

    // Helper to handle profile photo selection and potential upload
    private func handleProfilePhotoSelection(_ item: PhotosPickerItem?) {
        Task {
            if let data = try? await item?.loadTransferable(type: Data.self) {
                selectedImageData = data
                // Here you would typically upload the image data and get back a URL
                // For now, we'll just use the default avatar after selection
                _ = await authManager.updateProfile(
                    displayName: user?.displayName ?? "",
                    profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
                )
                await authManager.refreshProfile()
            }
        }
    }

    // Reusable view for the profile photo with edit button
    private func profilePhotoEditable(user: UserResponse) -> some View {
        VStack {
            Group {
                if let pictureURL = URL(string: user.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png") {
                    AsyncImage(url: pictureURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        ProgressView()
                    }
                    .frame(width: 90, height: 90)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                        .frame(width: 90, height: 90)
                }
            }
            Button {
                showPhotoPicker = true
            } label: {
                Text("Edit")
                    .font(.subheadline)
            }
        }
        .textCase(nil)
    }
}

#Preview {
    PersonalInformationView()
} 

