//
//  VerificationType.swift
//  Ecommerce
//
//  Created by User on 3/20/25.
//

import SwiftUI

enum VerificationType {
    case totpLogin(tempToken: String)
    case emailLogin(tempToken: String)
    case initialEmail
    case setupEmail2FA
    case disableEmail2FA
    case setupTOTP
    case disableTOTP

    /// Represents the source/context of the verification flow
    enum VerificationSource {
        case registration    // During initial registration
        case account        // From account settings
        case emailUpdate    // After email update
        case login2FA       // During login with 2FA
    }

    var source: VerificationSource {
        switch self {
        case .emailLogin:
            return .login2FA
        case .initialEmail:
            return .registration
        case .setupEmail2FA, .disableEmail2FA, .setupTOTP, .disableTOTP:
            return .account
        case .totpLogin:
            return .login2FA
        }
    }

    var title: String {
        switch self {
        case .totpLogin:
            return "Two-Factor Authentication"
        case .emailLogin:
            return "Two-Factor Authentication"
        case .initialEmail:
            return "Verify Your Email"
        case .setupEmail2FA:
            return "Set Up Email Verification"
        case .disableEmail2FA:
            return "Verify Identity"
        case .setupTOTP:
            return "Set Up Authenticator"
        case .disableTOTP:
            return "Verify Identity"
        }
    }

    var icon: (name: String, color: Color) {
        switch self {
        case .totpLogin, .setupTOTP, .disableTOTP:
            return ("lock.shield.fill", .blue)
        case .emailLogin, .initialEmail, .setupEmail2FA, .disableEmail2FA:
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
        case .emailLogin:
            message = "We've sent a verification code to \(userEmail). Please enter it below to complete login."
        case .setupEmail2FA:
            message = "We've sent a verification code to \(userEmail). Please enter it below to enable email verification."
        case .disableEmail2FA:
            message = "We've sent a verification code to \(userEmail). Please enter it below to disable email verification."
        case .totpLogin:
            message = "Enter the 6-digit code from your authenticator app to complete login."
        case .setupTOTP:
            message = "Enter the 6-digit code from your authenticator app to enable two-factor authentication."
        case .disableTOTP:
            message = "Enter the 6-digit code from your authenticator app to disable two-factor authentication."
        }
        return Text(.init(localized: message))

    }

    var buttonTitle: String {
        switch self {
        case .totpLogin, .emailLogin:
            return "Verify"
        case .initialEmail:
            return "Verify Email"
        case .setupEmail2FA:
            return "Verify and Enable"
        case .disableEmail2FA:
            return "Verify and Disable"
        case .setupTOTP:
            return "Verify and Enable"
        case .disableTOTP:
            return "Verify and Disable"
        }
    }

    var isEmailVerification: Bool {
        switch self {
        case .emailLogin, .initialEmail, .setupEmail2FA, .disableEmail2FA:
            return true
        case .totpLogin, .setupTOTP, .disableTOTP:
            return false
        }
    }

    var showsResendButton: Bool {
        switch self {
        case .emailLogin, .initialEmail, .setupEmail2FA, .disableEmail2FA:
            return true
        default:
            return false
        }
    }

    var showsSkipButton: Bool {
        switch self {
        case .initialEmail:
            return true
        default:
            return false
        }
    }
}
