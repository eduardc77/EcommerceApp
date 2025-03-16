import SwiftUI

struct ValidatedFormField<Field: Hashable>: View {
    let title: String
    @Binding var text: String
    let field: Field
    @FocusState.Binding var focusedField: Field?
    let error: String?
    let validate: () -> Void
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .sentences
    var secureField: Bool = false
    var isConfirmField: Bool = false
    
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if secureField {
                ZStack(alignment: .trailing) {
                    Group {
                        SecureField(title, text: $text)
                            .opacity(isSecure ? 1 : 0)
                        
                        TextField(title, text: $text)
                            .opacity(isSecure ? 0 : 1)
                    }
                    .textContentType(isConfirmField ? .password : .newPassword)
                    .focused($focusedField, equals: field)
                    .onChange(of: text) { _, _ in
                        if error != nil {
                            withAnimation(.smooth) {
                                validate()
                            }
                        }
                    }
                    
                    Button(action: {
                        withAnimation {
                            isSecure.toggle()
                        }
                    }) {
                        Image(systemName: isSecure ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(.gray)
                    }
                    .padding(.trailing, 8)
                }
                .textFieldStyle(.roundedBorder)
            } else {
                TextField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(contentType)
                    .textInputAutocapitalization(capitalization)
                    .keyboardType(keyboardType)
                    .focused($focusedField, equals: field)
                    .onChange(of: text) { _, _ in
                        if error != nil {
                            withAnimation(.smooth) {
                                validate()
                            }
                        }
                    }
            }
            
            if let error = error {
                errorMessage(error)
            }
        }
        .clipped()
    }
    
    private func errorMessage(_ error: String) -> some View {
        Text(error)
            .foregroundColor(.red)
            .font(.caption)
            .transition(
                .asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                )
            )
    }
} 
