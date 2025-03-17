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
    var isNewPassword: Bool = false

    @State private var showSecureText = true

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if secureField {
                ZStack(alignment: .trailing) {
                    Group {
                        SecureField(title, text: $text)
                            .textContentType(!isNewPassword ? .password : .newPassword)
                            .opacity(showSecureText ? 1 : 0)

                        TextField(title, text: $text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .opacity(showSecureText ? 0 : 1)
                    }
                    .textFieldStyle(.plain)
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
                            showSecureText.toggle()
                        }
                    }) {
                        Image(systemName: showSecureText ? "eye.fill" : "eye.slash.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }

            } else {
                TextField(title, text: $text)
                    .textFieldStyle(.plain)
                    .textContentType(contentType)
                    .textInputAutocapitalization(capitalization)
                    .autocorrectionDisabled()
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
    }
}
