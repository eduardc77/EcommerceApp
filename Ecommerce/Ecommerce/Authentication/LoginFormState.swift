import Foundation
import Observation

@Observable
final class LoginFormState {
    var identifier = ""
    var password = ""
    
    var fieldErrors: [String: String] = [:]
    var isValid = false
    
    func validateAll() {
        validateIdentifier(ignoreEmpty: false)
        validatePassword(ignoreEmpty: false)
    }
    
    func validateIdentifier(ignoreEmpty: Bool = true) {
        if identifier.isEmpty {
            if !ignoreEmpty {
                fieldErrors["identifier"] = "Username or email is required"
            } else {
                fieldErrors.removeValue(forKey: "identifier")
            }
        } else if identifier.count < 3 {
            fieldErrors["identifier"] = "Username or email must be at least 3 characters"
        } else {
            fieldErrors.removeValue(forKey: "identifier")
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
            fieldErrors["password"] = "Password must be at least 12 characters"
        } else {
            fieldErrors.removeValue(forKey: "password")
        }
        updateValidState()
    }
    
    private func updateValidState() {
        isValid = identifier.count >= 3 &&
                 !password.isEmpty &&
                 fieldErrors.isEmpty
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format:"SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    func reset() {
        identifier = ""
        password = ""
        fieldErrors = [:]
        isValid = false
    }
} 
