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
            validateCurrentPassword(ignoreEmpty: false)
        } else {
            validateCode(ignoreEmpty: false)
        }
        validateNewPassword(ignoreEmpty: false)
        validateConfirmPassword(ignoreEmpty: false)
    }
    
    func validateCode(ignoreEmpty: Bool = true) {
        if code.isEmpty {
            if !ignoreEmpty {
                fieldErrors["code"] = "Verification code is required"
            } else {
                fieldErrors.removeValue(forKey: "code")
            }
        } else if code.count != 6 || !code.allSatisfy({ $0.isNumber }) {
            fieldErrors["code"] = "Please enter a valid 6-digit code"
        } else {
            fieldErrors.removeValue(forKey: "code")
        }
        updateValidState()
    }
    
    func validateCurrentPassword(ignoreEmpty: Bool = true) {
        if currentPassword.isEmpty {
            if !ignoreEmpty {
                fieldErrors["currentPassword"] = "Current password is required"
            } else {
                fieldErrors.removeValue(forKey: "currentPassword")
            }
        } else if currentPassword.count < 8 {
            fieldErrors["currentPassword"] = "Password must be at least 8 characters"
        } else {
            fieldErrors.removeValue(forKey: "currentPassword")
        }
        updateValidState()
    }
    
    func validateNewPassword(ignoreEmpty: Bool = true) {
        if newPassword.isEmpty {
            if !ignoreEmpty {
                fieldErrors["newPassword"] = "New password is required"
            } else {
                fieldErrors.removeValue(forKey: "newPassword")
            }
            return
        }
        
        // Length check
        if newPassword.count < 12 {
            fieldErrors["newPassword"] = "Password must be at least 12 characters long"
            return
        } else if newPassword.count > 64 {
            fieldErrors["newPassword"] = "Password must not exceed 64 characters"
            return
        }
        
        // Complexity checks
        let hasUppercase = newPassword.contains(where: { $0.isUppercase })
        let hasLowercase = newPassword.contains(where: { $0.isLowercase })
        let hasNumber = newPassword.contains(where: { $0.isNumber })
        let hasSpecialChar = newPassword.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
        
        var requirements: [String] = []
        if !hasUppercase { requirements.append("uppercase letter") }
        if !hasLowercase { requirements.append("lowercase letter") }
        if !hasNumber { requirements.append("number") }
        if !hasSpecialChar { requirements.append("special character") }
        
        if !requirements.isEmpty {
            let missing = requirements.joined(separator: ", ")
            fieldErrors["newPassword"] = "Password is missing a required \(missing)"
            return
        }
        
        // Check for keyboard patterns
        let keyboardPattern = """
            (?:qwerty|asdfgh|zxcvbn|dvorak|qwertz|azerty|
            1qaz|2wsx|3edc|4rfv|5tgb|6yhn|7ujm|8ik|9ol|0p|
            zaq1|xsw2|cde3|vfr4|bgt5|nhy6|mju7|ki8|lo9|p0|
            qayz|wsxc|edcv|rfvb|tgbn|yhnm|ujm|ikol|polp)
            """
        
        if let regex = try? NSRegularExpression(pattern: keyboardPattern, options: [.allowCommentsAndWhitespace]),
           let _ = regex.firstMatch(in: newPassword.lowercased(), options: [], range: NSRange(location: 0, length: newPassword.utf8.count)) {
            fieldErrors["newPassword"] = "Password contains a keyboard pattern (like 'qwerty' or 'asdfgh')"
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
        
        let lowercasePassword = newPassword.lowercased()
        for pattern in sequentialPatterns {
            let patternLength = 3 // Minimum length to consider as a pattern
            for i in 0...(pattern.count - patternLength) {
                let slice = pattern[i..<(i + patternLength)]
                let forward = String(slice)
                let backward = String(slice.reversed())
                
                if lowercasePassword.contains(forward) || lowercasePassword.contains(backward) {
                    fieldErrors["newPassword"] = "Password contains a sequential pattern ('\(forward)')"
                    return
                }
            }
        }
        
        // Check for repeated characters
        let groups = Dictionary(grouping: newPassword, by: { $0 })
        if let (char, _) = groups.first(where: { $0.value.count >= 3 }) {
            fieldErrors["newPassword"] = "Password contains too many repeated characters ('\(char)')"
            return
        }
        
        // Check if new password is same as current
        if !currentPassword.isEmpty && newPassword == currentPassword {
            fieldErrors["newPassword"] = "New password must be different from current password"
            return
        }
        
        fieldErrors.removeValue(forKey: "newPassword")
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