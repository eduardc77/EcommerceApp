//
//  EmailVerificationDisableView.swift
//  Ecommerce
//
//  Created by User on 3/19/25.
//

import SwiftUI

struct EmailVerificationDisableView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(\.dismiss) private var dismiss
    @State private var verificationCode = ""
    @State private var error: Error?
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter the 6-digit verification code sent to your email")
                        .font(.headline)
                    
                    OneTimeCodeInput(code: $verificationCode, codeLength: 6)
                        .focused($isCodeFieldFocused)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    
                    AsyncButton {
                        do {
                            try await emailVerificationManager.disable2FA(code: verificationCode)
                            dismiss()
                            await authManager.signOut()
                        } catch {
                            self.error = error
                        }
                    } label: {
                        Text("Verify and Disable")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(verificationCode.count != 6)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Verify Identity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Verification Failed", isPresented: .init(
            get: { error != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK") {
                error = nil
            }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
        .onAppear {
            isCodeFieldFocused = true
        }
    }
}
