import SwiftUI

struct OneTimeCodeInput: View {
    @Binding var code: String
    let codeLength: Int
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<codeLength, id: \.self) { index in
                ZStack {
                    if index < code.count {
                        Text(String(code[code.index(code.startIndex, offsetBy: index)]))
                            .font(.title2.monospaced())
                            .fontWeight(.bold)
                    }
                }
                .frame(width: 40, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.background)
                        .strokeBorder(
                            isFocused ? (
                                code.count == codeLength ? (index == codeLength - 1 ? Color.accentColor : Color.secondary) :
                                index == code.count ? Color.accentColor : 
                                index < code.count ? Color.secondary : Color.secondary.opacity(0.2)
                            ) : (
                                index < code.count ? Color.secondary : Color.secondary.opacity(0.2)
                            ),
                            lineWidth: isFocused && (index == code.count || (code.count == codeLength && index == codeLength - 1)) ? 2 : 1
                        )
                }
            }
        }
        .overlay {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(0.001)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
        .onChange(of: code) { _, newValue in
            // Ensure only numbers and limit length
            code = String(newValue.filter { $0.isNumber }.prefix(codeLength))
        }
    }
}

#Preview {
    @Previewable @State var code = ""
    return OneTimeCodeInput(code: $code, codeLength: 6)
        .padding()
}
