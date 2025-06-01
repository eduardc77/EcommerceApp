import Foundation
import Observation

@Observable
final class SignUpFormState {
    // MARK: - Properties
    var email = ""
    var password = ""
    var confirmPassword = ""
    var username = ""
    var displayName = ""
    
    var fieldErrors: [String: String] = [:]
    var isValid = false
    
    func validateAll() {
        validateUsername()
        validateDisplayName()
        validateEmail()
        validatePassword()
        validateConfirmPassword()
    }
    
    func validateEmail() {
        if email.isEmpty {
            fieldErrors["email"] = "Email is required"
        } else if !isValidEmail(email) {
            fieldErrors["email"] = "Please enter a valid email"
        } else {
            fieldErrors.removeValue(forKey: "email")
        }
        updateValidState()
    }
    
    func validatePassword() {
        if password.isEmpty {
            fieldErrors["password"] = "Password is required"
        } else {
            // Use shared password validator
            if let errorMessage = PasswordValidator.validateWithMessage(password) {
                fieldErrors["password"] = errorMessage
            } else {
                fieldErrors.removeValue(forKey: "password")
            }
        }
        validateConfirmPassword()
        updateValidState()
    }
    
    func validateConfirmPassword() {
        if confirmPassword.isEmpty {
            fieldErrors["confirmPassword"] = "Please confirm your password"
        } else if confirmPassword != password {
            fieldErrors["confirmPassword"] = "Passwords do not match"
        } else {
            fieldErrors.removeValue(forKey: "confirmPassword")
        }
        updateValidState()
    }
    
    func validateUsername() {
        if username.isEmpty {
            fieldErrors["username"] = "Username is required"
        } else {
            // Username can only contain letters, numbers, hyphens and underscores
            let usernameRegex = "^[a-zA-Z0-9_-]+$"
            if username.range(of: usernameRegex, options: .regularExpression) == nil {
                fieldErrors["username"] = "Username can only contain letters, numbers, hyphens and underscores"
            } else {
                fieldErrors.removeValue(forKey: "username")
            }
        }
        updateValidState()
    }
    
    func validateDisplayName() {
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName.isEmpty {
            fieldErrors["displayName"] = "Display name is required"
        } else if trimmedDisplayName.isEmpty {
            fieldErrors["displayName"] = "Display name cannot be empty or only whitespace"
        } else if displayName.count > 100 {
            fieldErrors["displayName"] = "Display name must not exceed 100 characters"
        } else {
            fieldErrors.removeValue(forKey: "displayName")
        }
        updateValidState()
    }
    
    private func updateValidState() {
        isValid = username.count >= 3 &&
                 !displayName.isEmpty &&
                 isValidEmail(email) &&
                 password.count >= 12 &&
                 confirmPassword == password &&
                 fieldErrors.isEmpty  // This ensures all validation rules pass
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func reset() {
        email = ""
        password = ""
        confirmPassword = ""
        username = ""
        displayName = ""
        fieldErrors = [:]
        isValid = false
    }
}

// MARK: - Field Enum
enum Field: CaseIterable {
    case email
    case password
    case confirmPassword
    case username
    case displayName
} 
