//
//  DisableTOTPView.swift
//  Ecommerce
//
//  Created by User on 3/19/25.
//

import SwiftUI

struct TOTPDisableView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var disableTOTPCode = ""
    @State private var disableTOTPError: Error?

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Enter the 6-digit verification code from your authenticator app")
                        .font(.headline)

                    TextField("Verification Code", text: $disableTOTPCode)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                        .font(.system(.title2, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .onChange(of: disableTOTPCode) { oldValue, newValue in
                            // Limit to 6 digits
                            if newValue.count > 6 {
                                disableTOTPCode = String(newValue.prefix(6))
                            }
                            // Remove non-digits
                            disableTOTPCode = newValue.filter { $0.isNumber }
                        }

                    AsyncButton {
                        do {
                            try await authManager.totpManager.disableTOTP(code: disableTOTPCode)
                            dismiss()
                            await authManager.signOut()
                        } catch {
                            disableTOTPError = error
                        }
                    } label: {
                        Text("Verify and Disable")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(disableTOTPCode.count != 6)
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
            get: { disableTOTPError != nil },
            set: { if !$0 { disableTOTPError = nil } }
        )) {
            Button("OK") {
                disableTOTPError = nil
            }
        } message: {
            if let error = disableTOTPError {
                Text(error.localizedDescription)
            }
        }
    }
}
