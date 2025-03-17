import Foundation
import Observation

@Observable
final class RegisterFormState {
    // MARK: - Properties
    var email = ""
    var password = ""
    var confirmPassword = ""
    var username = ""
    var displayName = ""
    
    var fieldErrors: [String: String] = [:]
    var isValid = false
    
    func validateAll() {
        validateUsername(ignoreEmpty: false)
        validateDisplayName(ignoreEmpty: false)
        validateEmail(ignoreEmpty: false)
        validatePassword(ignoreEmpty: false)
        validateConfirmPassword(ignoreEmpty: false)
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
        } else {
            // Length check
            if password.count < 12 {
                fieldErrors["password"] = "Password must be at least 12 characters long"
            } else if password.count > 64 {
                fieldErrors["password"] = "Password must not exceed 64 characters"
            }
            // Complexity checks
            else {
                let hasUppercase = password.contains(where: { $0.isUppercase })
                let hasLowercase = password.contains(where: { $0.isLowercase })
                let hasNumber = password.contains(where: { $0.isNumber })
                let hasSpecialChar = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
                
                var requirements: [String] = []
                if !hasUppercase { requirements.append("uppercase letter") }
                if !hasLowercase { requirements.append("lowercase letter") }
                if !hasNumber { requirements.append("number") }
                if !hasSpecialChar { requirements.append("special character") }
                
                if !requirements.isEmpty {
                    let missing = requirements.joined(separator: ", ")
                    fieldErrors["password"] = "Password is missing a required \(missing)"
                    return
                }
                
                // Check for keyboard patterns using the same regex as backend
                let keyboardPattern = """
                    (?:qwerty|asdfgh|zxcvbn|dvorak|qwertz|azerty|
                    1qaz|2wsx|3edc|4rfv|5tgb|6yhn|7ujm|8ik|9ol|0p|
                    zaq1|xsw2|cde3|vfr4|bgt5|nhy6|mju7|ki8|lo9|p0|
                    qayz|wsxc|edcv|rfvb|tgbn|yhnm|ujm|ikol|polp)
                    """
                
                if let regex = try? NSRegularExpression(pattern: keyboardPattern, options: [.allowCommentsAndWhitespace]),
                   let _ = regex.firstMatch(in: password.lowercased(), options: [], range: NSRange(location: 0, length: password.utf8.count)) {
                    fieldErrors["password"] = "Password contains a keyboard pattern (like 'qwerty' or 'asdfgh')"
                    return
                }
                
                // Check for sequential patterns
                let sequentialPatterns = [
                    Array("abcdefghijklmnopqrstuvwxyz"),
                    Array("0123456789"),
                    Array("qwertyuiop"),
                    Array("asdfghjkl"),
                    Array("zxcvbnm")
                ]
                
                let lowercasePassword = password.lowercased()
                for pattern in sequentialPatterns {
                    let patternLength = 3 // Minimum length to consider as a pattern
                    for i in 0...(pattern.count - patternLength) {
                        let slice = pattern[i..<(i + patternLength)]
                        let forward = String(slice)
                        let backward = String(slice.reversed())
                        
                        if lowercasePassword.contains(forward) || lowercasePassword.contains(backward) {
                            fieldErrors["password"] = "Password contains a sequential pattern ('\(forward)')"
                            return
                        }
                    }
                }
                
                // Check for repeated characters
                let groups = Dictionary(grouping: password, by: { $0 })
                if let (char, _) = groups.first(where: { $0.value.count >= 3 }) {
                    fieldErrors["password"] = "Password contains too many repeated characters ('\(char)')"
                    return
                }
                
                fieldErrors.removeValue(forKey: "password")
            }
        }
        validateConfirmPassword()
        updateValidState()
    }
    
    func validateConfirmPassword(ignoreEmpty: Bool = true) {
        if confirmPassword.isEmpty {
            if !ignoreEmpty {
                fieldErrors["confirmPassword"] = "Please confirm your password"
            } else {
                fieldErrors.removeValue(forKey: "confirmPassword")
            }
        } else if confirmPassword != password {
            fieldErrors["confirmPassword"] = "Passwords do not match"
        } else {
            fieldErrors.removeValue(forKey: "confirmPassword")
        }
        updateValidState()
    }
    
    func validateUsername(ignoreEmpty: Bool = true) {
        if username.isEmpty {
            if !ignoreEmpty {
                fieldErrors["username"] = "Username is required"
            } else {
                fieldErrors.removeValue(forKey: "username")
            }
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
    
    func validateDisplayName(ignoreEmpty: Bool = true) {
        if displayName.isEmpty {
            if !ignoreEmpty {
                fieldErrors["displayName"] = "Display name is required"
            } else {
                fieldErrors.removeValue(forKey: "displayName")
            }
        } else if displayName.count < 2 {
            fieldErrors["displayName"] = "Display name must be at least 2 characters"
        } else if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            fieldErrors["displayName"] = "Display name cannot be only whitespace"
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
