//
//  VerificationType.swift
//  Ecommerce
//
//  Created by User on 3/20/25.
//

import SwiftUI

public enum VerificationType {
    case emailSignIn(stateToken: String)
    case totpSignIn(stateToken: String)
    case initialEmail(stateToken: String, email: String)
    case initialEmailFromAccountSettings(email: String)
    case enableEmailMFA(email: String)
    case enableTOTP

    /// Represents the source/context of the verification flow
    enum VerificationSource {
        case registration    // During initial registration
        case account        // From account settings
        case emailUpdate    // After email update
        case signInMFA      // During sign in with MFA
    }

    var source: VerificationSource {
        switch self {
        case .emailSignIn:
            return .signInMFA
        case .initialEmail:
            return .registration
        case .enableEmailMFA, .enableTOTP:
            return .account
        case .totpSignIn:
            return .signInMFA
        case .initialEmailFromAccountSettings:
            return .account
        }
    }

    var verificationType: VerificationType {
        return self
    }

    var isSignIn: Bool {
        switch self {
        case .totpSignIn, .emailSignIn:
            return true
        default:
            return false
        }
    }

    var isSetup: Bool {
        switch self {
        case .enableTOTP, .enableEmailMFA:
            return true
        default:
            return false
        }
    }

    var isEmail: Bool {
        switch self {
        case .emailSignIn, .initialEmail, .initialEmailFromAccountSettings, .enableEmailMFA:
            return true
        default:
            return false
        }
    }

    var isTOTP: Bool {
        switch self {
        case .totpSignIn, .enableTOTP:
            return true
        default:
            return false
        }
    }

    var isSignInOrSignUp: Bool {
        switch self {
        case .emailSignIn, .totpSignIn, .initialEmail:
            return true
        default:
            return false
        }
    }

    var message: String {
        switch self {
        case .emailSignIn:
            return "We've sent a verification code to your email. Please enter it below to complete sign in."
        case .initialEmail:
            return "We've sent a verification code to your email. Please enter it below to verify your email address."
        case .enableEmailMFA:
            return "We've sent a verification code to your email. Please enter it below to enable email MFA."
        case .enableTOTP:
            return "Please enter the verification code from your authenticator app to enable TOTP MFA."
        case .totpSignIn:
            return "Please enter the verification code from your authenticator app to sign in."
        case .initialEmailFromAccountSettings:
            return "We've sent a verification code to your email. Please enter it below to verify your email address."
        }
    }

    var title: String {
        switch self {
        case .emailSignIn:
            return "Verify Email"
        case .initialEmail:
            return "Verify Email"
        case .enableEmailMFA:
            return "Set Up Email MFA"
        case .enableTOTP:
            return "Set Up TOTP MFA"
        case .totpSignIn:
            return "Verify TOTP"
        case .initialEmailFromAccountSettings:
            return "Verify Email"
        }
    }

    var icon: (name: String, color: Color) {
        switch self {
        case .totpSignIn, .enableTOTP:
            return ("lock.shield.fill", .blue)
        case .emailSignIn, .initialEmail, .enableEmailMFA:
            return ("envelope.badge.shield.half.filled.fill", .blue)
        case .initialEmailFromAccountSettings:
            return ("envelope.badge.shield.half.filled.fill", .blue)
        }
    }

    func descriptionText(email: String?) -> Text {
        let userEmail: String
        if let email = email {
            userEmail = "**\(email)**"
        } else {
            userEmail = "your email"
        }

        let message: LocalizedStringResource
        switch self {
        case .initialEmail:
            message = "We've sent a verification code to \(userEmail). Please enter it below to verify your account."
        case .emailSignIn:
            message = "We've sent a verification code to \(userEmail). Please enter it below to complete sign in."
        case .enableEmailMFA:
            message = "We've sent a verification code to \(userEmail). Please enter it below to enable email verification."
        case .totpSignIn:
            message = "Enter the 6-digit code from your authenticator app to complete sign in."
        case .enableTOTP:
            message = "Enter the 6-digit code from your authenticator app to enable two-factor authentication."
        case .initialEmailFromAccountSettings:
            message = "We've sent a verification code to \(userEmail). Please enter it below to verify your email address."
        }
        return Text(.init(localized: message))
    }

    var buttonTitle: String {
        switch self {
        case .emailSignIn, .initialEmail, .initialEmailFromAccountSettings, .enableEmailMFA:
            return "Verify Code"
        case .enableTOTP:
            return "Enable MFA"
        case .totpSignIn:
            return "Verify Code"
        }
    }

    var showsResendButton: Bool {
        isEmail
    }

    var showsSkipButton: Bool {
        switch self {
        case .initialEmail:
            return true
        default:
            return false
        }
    }

    var resendButtonTitle: String {
        switch self {
        case .emailSignIn, .initialEmail, .initialEmailFromAccountSettings, .enableEmailMFA:
            return "Resend Code"
        case .enableTOTP, .totpSignIn:
            return ""
        }
    }

    var errorMessage: String {
        switch self {
        case .totpSignIn:
            return "Invalid authenticator code. Please try again."
        case .emailSignIn, .initialEmail, .initialEmailFromAccountSettings, .enableEmailMFA:
            return "Invalid verification code. Please check your email and try again."
        case .enableTOTP:
            return "Invalid authenticator code. Please make sure you entered the correct code from your authenticator app."
        }
    }

    var resendMessage: String {
        switch self {
        case .emailSignIn, .initialEmail, .initialEmailFromAccountSettings, .enableEmailMFA:
            return "A new verification code has been sent to your email."
        case .totpSignIn, .enableTOTP:
            return "Please check your authenticator app for the latest code."
        }
    }

    var stateToken: String {
        switch self {
        case .emailSignIn(let token), .totpSignIn(let token), .initialEmail(let token, _):
            return token
        case .enableEmailMFA, .enableTOTP:
            return ""
        case .initialEmailFromAccountSettings(let email):
            return email
        }
    }
}
