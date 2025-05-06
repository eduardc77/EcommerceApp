import Foundation
import GoogleSignIn
import SwiftUI

@Observable
@MainActor
public final class SocialAuthManager {
    private let authManager: AuthManagerProtocol
    public var error: Error?
    public var isLoading = false
    
    init(authManager: AuthManagerProtocol) {
        self.authManager = authManager
    }
    
    func signInWithGoogle() async throws {
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
                    Task { @MainActor in
                        continuation.resume(returning: signInResult)
                    }
                }
            }
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthenticationError.invalidCredentials
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            // Get the response from the auth service and let auth manager handle it
            _ = try await authManager.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        } catch {
            self.error = error
            throw error
        }
    }
}
