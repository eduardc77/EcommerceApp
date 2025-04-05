import SwiftUI

struct RecoveryCodeEntryView: View {
    let stateToken: String
    @Environment(AuthenticationManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var recoveryCode = ""
    @State private var isLoading = false
    @State private var error: Error?
    @State private var showError = false
    @FocusState private var isInputFocused: Bool
    
    // Format: xxxx-xxxx-xxxx-xxxx
    private let codeLength = 19
    private let groupSize = 4
    private let separator = "-"
    
    var formattedCode: String {
        let cleaned = recoveryCode.filter { $0.isNumber || $0.isLetter }
        var result = ""
        var index = 0
        
        for char in cleaned {
            if index > 0 && index % groupSize == 0 && index < 16 {
                result += separator
            }
            result.append(char)
            index += 1
        }
        
        return String(result.prefix(codeLength))
    }
    
    var isValidFormat: Bool {
        let cleaned = recoveryCode.filter { $0.isNumber || $0.isLetter }
        return cleaned.count == 16
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "key.horizontal.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.tint)
                            .symbolEffect(.bounce, value: isInputFocused)
                        
                        VStack(spacing: 8) {
                            Text("Enter Recovery Code")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Enter one of your recovery codes to sign in to your account.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical)
                    
                    TextField("xxxx-xxxx-xxxx-xxxx", text: $recoveryCode)
                        .textContentType(.oneTimeCode)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .focused($isInputFocused)
                        .onChange(of: recoveryCode) { oldValue, newValue in
                            recoveryCode = formattedCode
                        }
                }
                
                Section {
                    Button {
                        Task {
                            await verifyCode()
                        }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Continue")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValidFormat || isLoading)
                }
            }
            .navigationTitle("Recovery Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                if let error = error {
                    Text(error.localizedDescription)
                }
            }
            .onAppear {
                isInputFocused = true
            }
        }
    }
    
    private func verifyCode() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await authManager.recoveryCodesManager.verifyCode(
                code: recoveryCode.replacingOccurrences(of: "-", with: ""),
                stateToken: stateToken
            )
            await authManager.completeSignIn(response: response)
            dismiss()
        } catch let error as RecoveryCodesError {
            // Log the error for debugging
            print("DEBUG: Recovery code error in verifyCode(): \(error)")
            
            // Convert recovery code error to user-friendly error
            switch error {
            case .networkError(let networkError):
                self.error = interpretNetworkError(networkError as! NetworkError)
            case .invalidCode:
                self.error = NSError(
                    domain: "RecoveryCodeError",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid recovery code. Please check and try again."]
                )
                recoveryCode = ""
                isInputFocused = true
            case .verificationFailed:
                self.error = NSError(
                    domain: "RecoveryCodeError",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to verify recovery code. Please try again."]
                )
            default:
                self.error = NSError(
                    domain: "RecoveryCodeError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]
                )
            }
            showError = true
        } catch {
            // For any other errors, try to get a more specific error message
            if let nsError = error as NSError? {
                self.error = NSError(
                    domain: "RecoveryCodeError",
                    code: nsError.code,
                    userInfo: [NSLocalizedDescriptionKey: nsError.localizedDescription]
                )
            } else {
                self.error = NSError(
                    domain: "RecoveryCodeError",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."]
                )
            }
            showError = true
        }
    }
    
    private func interpretNetworkError(_ error: NetworkError) -> Error {
        switch error {
        case .clientError(let statusCode, _, _, let data):
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorData = json["error"] as? [String: Any],
               let message = errorData["message"] as? String {
                return NSError(
                    domain: "RecoveryCodeError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            }
            
            // Fallback error messages based on status code
            if statusCode == 400 {
                return NSError(
                    domain: "RecoveryCodeError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid recovery code. Please check and try again."]
                )
            } else if statusCode == 401 {
                return NSError(
                    domain: "RecoveryCodeError",
                    code: statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "Your session has expired. Please try signing in again."]
                )
            }
            return NSError(
                domain: "RecoveryCodeError",
                code: statusCode,
                userInfo: [NSLocalizedDescriptionKey: "An error occurred while verifying your recovery code. Please try again."]
            )
            
        case .networkConnectionLost:
            return NSError(
                domain: "RecoveryCodeError",
                code: -1009,
                userInfo: [NSLocalizedDescriptionKey: "Connection lost. Please check your internet connection and try again."]
            )
        case .cannotConnectToHost:
            return NSError(
                domain: "RecoveryCodeError",
                code: -1004,
                userInfo: [NSLocalizedDescriptionKey: "Cannot connect to server. Please try again later."]
            )
        case .dnsLookupFailed:
            return NSError(
                domain: "RecoveryCodeError",
                code: -1003,
                userInfo: [NSLocalizedDescriptionKey: "DNS lookup failed. Please check your internet connection."]
            )
        case .cannotFindHost:
            return NSError(
                domain: "RecoveryCodeError",
                code: -1003,
                userInfo: [NSLocalizedDescriptionKey: "Cannot find server. Please try again later."]
            )
        case .timeout:
            return NSError(
                domain: "RecoveryCodeError",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "The request timed out. Please try again."]
            )
        case .unauthorized(let description):
            return NSError(
                domain: "RecoveryCodeError",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: description.isEmpty ? "Your session has expired. Please try signing in again." : description]
            )
        case .badRequest(let description):
            return NSError(
                domain: "RecoveryCodeError",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: description.isEmpty ? "Invalid recovery code. Please check and try again." : description]
            )
        default:
            return NSError(
                domain: "RecoveryCodeError",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "An unexpected error occurred. Please try again."]
            )
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

    let totpService = PreviewTOTPService()
    let totpManager = TOTPManager(totpService: totpService)
    let emailVerificationService = PreviewEmailVerificationService()
    let emailVerificationManager = EmailVerificationManager(emailVerificationService: emailVerificationService)
    let recoeryCodesService = PreviewRecoveryCodesService()
    let recoveryCodesManager = RecoveryCodesManager(recoveryCodesService: recoeryCodesService)

    let authManager = AuthenticationManager(
        authService: PreviewAuthenticationService(),
        userService: PreviewUserService(),
        totpManager: totpManager,
        emailVerificationManager: emailVerificationManager,
        recoveryCodesManager: recoveryCodesManager,
        authorizationManager: authorizationManager
    )

    RecoveryCodeEntryView(stateToken: "preview-token")
        .environment(authManager)
        .environment(emailVerificationManager)
        .environment(totpManager)
}
#endif
