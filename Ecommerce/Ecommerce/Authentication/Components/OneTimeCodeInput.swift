//
//  OneTimeCodeInput.swift
//  Ecommerce
//
//  Created by User on 3/17/25.
//

import SwiftUI

struct OneTimeCodeInput: View {
    @Binding var code: String
    let codeLength: Int

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
                            index == code.count ? Color.accentColor :
                                index < code.count ? Color.secondary :
                                Color.secondary.opacity(0.2),
                            lineWidth: index == code.count ? 2 : 1
                        )
                }
            }
        }
        .overlay {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .allowsHitTesting(true)
                .opacity(0.001)
        }
        .onChange(of: code) { _, newValue in
            // Ensure only numbers and limit length
            code = String(newValue.filter { $0.isNumber }.prefix(codeLength))
        }
    }
}
