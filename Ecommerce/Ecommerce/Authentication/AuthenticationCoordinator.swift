import SwiftUI

@Observable
final class AuthenticationCoordinator {
    var navigationPath = NavigationPath()
    var authFlow: AuthFlow?
    
    enum AuthFlow: Identifiable {
        case totpVerification(stateToken: String)
        case emailVerification(stateToken: String)
        case mfaSelection(stateToken: String)
        case recoveryCodeVerification(stateToken: String)
        case resetPassword(email: String)
        
        var id: String {
            switch self {
            case .totpVerification: return "totp"
            case .emailVerification: return "email"
            case .mfaSelection: return "mfa-selection"
            case .recoveryCodeVerification: return "recovery-code"
            case .resetPassword: return "reset-password"
            }
        }
    }
    
    enum Route: Hashable {
        case signup
        case forgotPassword
        case resetPassword(email: String)
    }
    
    func navigateToSignUp() {
        navigationPath.append(Route.signup)
    }
    
    func navigateToForgotPassword() {
        navigationPath.append(Route.forgotPassword)
    }
    
    func navigateToResetPassword(email: String) {
        navigationPath.append(Route.resetPassword(email: email))
    }
    
    func showTOTPVerification(stateToken: String) {
        authFlow = .totpVerification(stateToken: stateToken)
    }
    
    func showEmailVerification(stateToken: String) {
        authFlow = .emailVerification(stateToken: stateToken)
    }
    
    func showMFASelection(stateToken: String) {
        authFlow = .mfaSelection(stateToken: stateToken)
    }
    
    func showRecoveryCodeVerification(stateToken: String) {
        authFlow = .recoveryCodeVerification(stateToken: stateToken)
    }
    
    func dismissFlow() {
        authFlow = nil
    }
    
    func popToRoot() {
        navigationPath.removeLast(navigationPath.count)
    }
} 