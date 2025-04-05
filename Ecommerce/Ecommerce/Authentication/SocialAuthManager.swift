import Foundation
import GoogleSignIn
import SwiftUI

@Observable
@MainActor
final class SocialAuthManager {
    private let authManager: AuthenticationManager
    public var error: Error?
    public var isLoading = false
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    func signInWithGoogle() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw AuthenticationError.unknown
            }
            
            let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GIDSignInResult, Error>) in
                GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { signInResult, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    guard let signInResult = signInResult else {
                        continuation.resume(throwing: AuthenticationError.invalidCredentials)
                        return
                    }
                    continuation.resume(returning: signInResult)
                }
            }

            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationError.invalidCredentials
            }
            
            // Get the response from the auth service and let auth manager handle it
            _ = try await authManager.signInWithGoogle(idToken: idToken)
        } catch {
            self.error = error
        }
    }
}
