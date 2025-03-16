import Foundation
import Observation

@Observable
final class LoginFormState {
    var email = ""
    var password = ""
    
    var fieldErrors: [String: String] = [:]
    var isValid = false
    
    func validateAll() {
        validateEmail(ignoreEmpty: false)
        validatePassword(ignoreEmpty: false)
    }
    
    func validateEmail(ignoreEmpty: Bool = true) {
        if email.isEmpty {
            if !ignoreEmpty {
                fieldErrors["email"] = "Email is required"
            } else {
                fieldErrors.removeValue(forKey: "email")
            }
        } else if !isValidEmail(email) {
            fieldErrors["email"] = "Please enter a valid email"
        } else {
            fieldErrors.removeValue(forKey: "email")
        }
        updateValidState()
    }
    
    func validatePassword(ignoreEmpty: Bool = true) {
        if password.isEmpty {
            if !ignoreEmpty {
                fieldErrors["password"] = "Password is required"
            } else {
                fieldErrors.removeValue(forKey: "password")
            }
        } else if password.count < 8 {
            fieldErrors["password"] = "Password must be at least 8 characters"
        } else {
            fieldErrors.removeValue(forKey: "password")
        }
        updateValidState()
    }
    
    private func updateValidState() {
        isValid = isValidEmail(email) && password.count >= 8
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func reset() {
        email = ""
        password = ""
        fieldErrors = [:]
        isValid = false
    }
} 