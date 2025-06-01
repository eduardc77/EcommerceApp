import Foundation
import Observation

@Observable
final class ResetPasswordFormState {
    // MARK: - Properties
    var code = ""
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
    var isChangePassword = false
    
    var fieldErrors: [String: String] = [:]
    var isValid = false
    
    func validateAll() {
        if isChangePassword {
            validateCurrentPassword()
        } else {
            validateCode()
        }
        validateNewPassword()
        validateConfirmPassword()
    }
    
    func validateCode() {
        if code.isEmpty {
            fieldErrors["code"] = "Verification code is required"
        } else if code.count != 6 || !code.allSatisfy({ $0.isNumber }) {
            fieldErrors["code"] = "Please enter a valid 6-digit code"
        } else {
            fieldErrors.removeValue(forKey: "code")
        }
        updateValidState()
    }
    
    func validateCurrentPassword() {
        if currentPassword.isEmpty {
            fieldErrors["currentPassword"] = "Current password is required"
        } else if currentPassword.count < 8 {
            fieldErrors["currentPassword"] = "Password must be at least 8 characters"
        } else {
            fieldErrors.removeValue(forKey: "currentPassword")
        }
        updateValidState()
    }
    
    func validateNewPassword() {
        if newPassword.isEmpty {
            fieldErrors["newPassword"] = "New password is required"
            return
        }
        
        // Use shared password validator, including check against current password
        let currentPasswordToCheck = isChangePassword ? currentPassword : nil
        if let errorMessage = PasswordValidator.validateWithMessage(newPassword, againstCurrentPassword: currentPasswordToCheck) {
            fieldErrors["newPassword"] = errorMessage
        } else {
            fieldErrors.removeValue(forKey: "newPassword")
        }
        
        validateConfirmPassword()
        updateValidState()
    }
    
    func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            fieldErrors["confirmPassword"] = "Please confirm your password"
        } else if confirmPassword != newPassword {
            fieldErrors["confirmPassword"] = "Passwords do not match"
        } else {
            fieldErrors.removeValue(forKey: "confirmPassword")
        }
        updateValidState()
    }
    
    private func updateValidState() {
        if isChangePassword {
            isValid = fieldErrors.isEmpty &&
                     !currentPassword.isEmpty &&
                     !newPassword.isEmpty &&
                     !confirmPassword.isEmpty
        } else {
            isValid = fieldErrors.isEmpty &&
                     !code.isEmpty &&
                     !newPassword.isEmpty &&
                     !confirmPassword.isEmpty &&
                     code.count == 6 &&
                     code.allSatisfy({ $0.isNumber })
        }
    }
    
    func reset() {
        code = ""
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        fieldErrors = [:]
        isValid = false
    }
}

// MARK: - Field Enum
enum ResetPasswordField: Hashable {
    case code
    case currentPassword
    case newPassword
    case confirmPassword
} 