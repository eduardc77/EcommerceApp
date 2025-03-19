//
//  EmailVerificationSetupView.swift
//  Ecommerce
//
//  Created by User on 3/19/25.
//

import SwiftUI

struct EmailVerificationSetupView: View {
    @Environment(EmailVerificationManager.self) private var emailVerificationManager
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var verificationCode = ""
    @State private var error: Error?
    @State private var isLoading = false
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
                        isLoading = true
                        do {
                            try await emailVerificationManager.verify2FA(code: verificationCode)
                            // Sign out after successful 2FA enable since server invalidates tokens
                            await authManager.signOut()
                            dismiss()
                        } catch {
                            self.error = error
                        }
                        isLoading = false
                    } label: {
                        Text("Verify and Enable")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(verificationCode.count != 6 || isLoading)
                }
                .padding(.vertical, 8)
            }
        }
        .navigationTitle("Set Up Email Verification")
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
        .disabled(isLoading)
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
        .onAppear {
            isCodeFieldFocused = true
        }
        .task {
            do {
                try await emailVerificationManager.setup2FA()
            } catch {
                self.error = error
            }
        }
    }
}
