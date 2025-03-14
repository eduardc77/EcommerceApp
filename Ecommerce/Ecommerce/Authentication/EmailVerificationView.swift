import SwiftUI

struct EmailVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var verificationCode = ""
    @State private var isShowingSkipAlert = false
    @State private var isResendingCode = false
    @State private var expirationTimer = Self.codeExpirationTime
    @State private var resendCooldown = 0
    @State private var isExpirationTimerRunning = false
    @State private var attempts = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Constants
    private static let codeExpirationTime = 300 // 5 minutes
    private static let resendCooldownTime = 120 // 2 minutes
    private let codeLength = 6
    private let maxAttempts = 3
    @FocusState private var isCodeFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header Section
                VStack(spacing: 16) {
                    Image(systemName: "envelope.badge.shield")
                        .font(.system(size: 60))
                        .symbolEffect(.bounce, options: .repeating)
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Verify Your Email")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let email = authManager.currentUser?.email {
                        Text("We've sent a verification code to \(email). Please enter it below to verify your account.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
                
                // Code Input Section
                VStack(spacing: 16) {
                    OneTimeCodeInput(code: $verificationCode, codeLength: codeLength)
                        .focused($isCodeFieldFocused)
                    
                    VStack(spacing: 8) {
                        if isExpirationTimerRunning {
                            Text("Code expires in \(formatTime(expirationTimer))")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        
                        if resendCooldown > 0 {
                            Text("Resend available in \(resendCooldown)s")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            Button(action: resendCode) {
                                Text("Resend Code")
                                    .font(.footnote)
                            }
                            .disabled(isResendingCode)
                        }
                    }
                    
                    if attempts > 0 {
                        Text("\(maxAttempts - attempts) attempts remaining")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: verifyCode) {
                        Text("Verify")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(verificationCode.count != codeLength || attempts >= maxAttempts)
                    
                    Button(action: { isShowingSkipAlert = true }) {
                        Text("Skip for now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .alert("Skip Verification?", isPresented: $isShowingSkipAlert) {
                Button("Continue without verifying", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can still use the app, but some features will be limited until you verify your email.")
            }
            .alert("Verification Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if authManager.isLoading {
                    ProgressView()
                        .background(.ultraThinMaterial)
                }
            }
        }
        .onAppear {
            isCodeFieldFocused = true
            startExpirationTimer()
            startResendCooldown()
        }
    }
    
    private func verifyCode() {
        guard attempts < maxAttempts else {
            errorMessage = "Too many attempts. Please request a new code."
            showError = true
            return
        }
        
        Task {
            attempts += 1
            let success = await authManager.verifyEmail(code: verificationCode)
            if success {
                dismiss()
            } else if let error = authManager.error {
                errorMessage = error.localizedDescription
                showError = true
                
                if attempts >= maxAttempts {
                    verificationCode = ""
                    isExpirationTimerRunning = false
                }
            }
        }
    }
    
    private func resendCode() {
        Task {
            isResendingCode = true
            await authManager.resendVerificationEmail()
            
            if authManager.error == nil {
                attempts = 0
                verificationCode = ""
                startExpirationTimer()
                startResendCooldown()
            } else {
                errorMessage = authManager.error?.localizedDescription ?? "Failed to resend code"
                showError = true
            }
            
            isResendingCode = false
        }
    }
    
    private func startExpirationTimer() {
        expirationTimer = Self.codeExpirationTime
        isExpirationTimerRunning = true
        
        Task {
            while expirationTimer > 0 {
                try? await Task.sleep(for: .seconds(1))
                expirationTimer -= 1
            }
            isExpirationTimerRunning = false
        }
    }
    
    private func startResendCooldown() {
        resendCooldown = Self.resendCooldownTime
        
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(for: .seconds(1))
                resendCooldown -= 1
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

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

#Preview {
    EmailVerificationView()
        .environment(AuthenticationManager(
            authService: PreviewAuthenticationService(),
            userService: PreviewUserService(),
            tokenStore: PreviewTokenStore(),
            totpService: PreviewTOTPService(),
            emailVerificationService: PreviewEmailVerificationService()
        ))
} 