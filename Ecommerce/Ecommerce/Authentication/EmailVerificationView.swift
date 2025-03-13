import SwiftUI

struct EmailVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    @State private var verificationCode = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Verify Your Email")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Please enter the verification code sent to your email.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                
                TextField("Verification Code", text: $verificationCode)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(maxWidth: 200)
                
                Button(action: verifyEmail) {
                    if authManager.isLoading {
                        ProgressView()
                    } else {
                        Text("Verify")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(authManager.isLoading || verificationCode.isEmpty)
                
                Button("Resend Code", action: resendCode)
                    .disabled(authManager.isLoading)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(authManager.error != nil)) {
                Button("OK") { authManager.error = nil }
            } message: {
                Text(authManager.error?.localizedDescription ?? "")
            }
        }
    }
    
    private func verifyEmail() {
        Task {
            if await authManager.verifyEmail(code: verificationCode) {
                dismiss()
            }
        }
    }
    
    private func resendCode() {
        Task {
            await authManager.resendVerificationEmail()
        }
    }
} 