import SwiftUI

enum VerificationSource {
    case registration    // During initial registration
    case account        // From account settings
    case emailUpdate    // After email update
}

struct EmailVerificationView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    let source: VerificationSource
    
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
            VStack {
                // Header Section
                VStack {
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
                VStack {
                    OneTimeCodeInput(code: $verificationCode, codeLength: codeLength)
                        .focused($isCodeFieldFocused)
                    
                    if showError {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack {
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
                            AsyncButton("Resend Code") {
                                await resendCode()
                            }
                            .font(.footnote)
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
                    AsyncButton("Verify") {
                        await verifyCode()
                    }
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
            .onChange(of: verificationCode) { oldValue, newValue in
                // Only clear error if user is actively typing a new code
                if newValue.count > oldValue.count {
                    showError = false
                    errorMessage = ""
                }
            }
            .alert("Skip Verification?", isPresented: $isShowingSkipAlert) {
                Button("Continue without verifying", role: .destructive) {
                    authManager.skipEmailVerification()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You can still use the app, but some features will be limited until you verify your email.")
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
            
            switch source {
            case .registration:
                // Code already sent during registration, just start timers
                startExpirationTimer()
                startResendCooldown()
            case .account, .emailUpdate:
                // Send new code and start timers
                Task {
                    await authManager.resendVerificationEmail()
                    if authManager.verificationError == nil {
                        startExpirationTimer()
                        startResendCooldown()
                    } else {
                        errorMessage = authManager.verificationError?.localizedDescription ?? VerificationError.unknown("Failed to send verification code").localizedDescription
                        showError = true
                    }
                }
            }
        }
    }
    
    private func startExpirationTimer() {
        expirationTimer = Self.codeExpirationTime
        isExpirationTimerRunning = true
        
        Task {
            while expirationTimer > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                expirationTimer -= 1
            }
            isExpirationTimerRunning = false
        }
    }
    
    private func startResendCooldown() {
        resendCooldown = Self.resendCooldownTime
        
        Task {
            while resendCooldown > 0 && !Task.isCancelled {
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
    
    private func verifyCode() async {
        guard attempts < maxAttempts else {
            withAnimation {
                errorMessage = VerificationError.tooManyAttempts.localizedDescription
                showError = true
            }
            return
        }
        
        attempts += 1
        let success = await authManager.verifyEmail(code: verificationCode)
        
        if success {
            dismiss()
        } else {
            withAnimation {
                errorMessage = authManager.verificationError?.localizedDescription ?? VerificationError.unknown("Verification failed").localizedDescription
                showError = true
                verificationCode = ""  // Clear code after setting error
                
                // If max attempts reached, stop the timer
                if attempts >= maxAttempts {
                    isExpirationTimerRunning = false
                }
            }
        }
    }
    
    private func resendCode() async {
        isResendingCode = true
        await authManager.resendVerificationEmail()
        
        if authManager.verificationError == nil {
            withAnimation {
                attempts = 0
                showError = false
                errorMessage = ""
                verificationCode = ""
                startExpirationTimer()
                startResendCooldown()
            }
        } else {
            withAnimation {
                errorMessage = authManager.verificationError?.localizedDescription ?? VerificationError.unknown("Failed to resend code").localizedDescription
                showError = true
            }
        }
        
        isResendingCode = false
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

#if DEBUG
import Networking

#Preview {
    // Create shared dependencies
    let tokenStore = PreviewTokenStore()
    let refreshClient = PreviewRefreshAPIClient()
    let authorizationManager = AuthorizationManager(
        refreshClient: refreshClient,
        tokenStore: tokenStore
    )

    EmailVerificationView(source: .registration)
        .environment(AuthenticationManager(
            authService: PreviewAuthenticationService(),
            userService: PreviewUserService(),
            totpService: PreviewTOTPService(),
            emailVerificationService: PreviewEmailVerificationService(),
            authorizationManager: authorizationManager
        ))
} 
#endif
