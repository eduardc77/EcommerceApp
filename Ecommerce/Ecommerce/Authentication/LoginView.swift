import SwiftUI

struct LoginView: View {
    @Environment(AuthenticationManager.self) private var authManager
    @State private var identifier = ""
    @State private var password = ""
    @State private var showRegistration = false
    
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
                }
                .padding(.horizontal)
                
                Button(action: login) {
                    if authManager.isLoading {
                        ProgressView()
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .disabled(authManager.isLoading)
                
                Button("Create Account") {
                    showRegistration = true
                }
                .sheet(isPresented: $showRegistration) {
                    RegisterView()
                }
            }
            .alert("Error", isPresented: .constant(authManager.error != nil)) {
                Button("OK") { authManager.error = nil }
            } message: {
                Text(authManager.error?.localizedDescription ?? "")
            }
        }
    }
    
    private func login() {
        Task {
            await authManager.signIn(identifier: identifier, password: password)
        }
    }
} 
