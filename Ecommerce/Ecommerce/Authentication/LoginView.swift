import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var identifier = ""
    @State private var password = ""
    @State private var totpCode = ""
    @State private var showRegistration = false
    @State private var showEmailVerification = false
    @State private var showTOTPVerification = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome Back")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 15) {
                    TextField("Email or Username", text: $identifier)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.username)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)
                    
                    if showTOTPVerification {
                        TextField("2FA Code", text: $totpCode)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                    }
                }
                .padding(.horizontal)
                
                Button(action: login) {
                    if authManager.isLoading {
                        ProgressView()
                    } else {
                        Text(showTOTPVerification ? "Verify" : "Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(authManager.isLoading)
                
                if !showTOTPVerification {
                    NavigationLink {
                        RegisterView()
                    } label: {
                        Text("Create Account")
                    }
                }
            }
            .alert("Error", isPresented: .constant(authManager.error != nil)) {
                Button("OK") { authManager.error = nil }
            } message: {
                Text(authManager.error?.localizedDescription ?? "")
            }
            .sheet(isPresented: $showEmailVerification) {
                EmailVerificationView()
            }
            .onChange(of: authManager.requires2FA) { _, requires2FA in
                showTOTPVerification = requires2FA
                if requires2FA {
                    totpCode = ""
                }
            }
            .onChange(of: authManager.requiresEmailVerification) { _, requiresEmailVerification in
                showEmailVerification = requiresEmailVerification
            }
        }
    }
    
    private func login() {
        Task {
            if showTOTPVerification {
                await authManager.signIn(identifier: identifier, password: password, totpCode: totpCode)
            } else {
                await authManager.signIn(identifier: identifier, password: password)
            }
        }
    }
} 
