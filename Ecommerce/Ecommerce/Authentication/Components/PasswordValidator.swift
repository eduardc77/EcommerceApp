import Foundation

struct PasswordValidator {
    
    enum ValidationError: Error, LocalizedError {
        case tooShort
        case tooLong
        case missingUppercase
        case missingLowercase  
        case missingNumber
        case missingSpecialCharacter
        case multipleRequirements([String])
        case keyboardPattern(String)
        case sequentialPattern(String)
        case repeatedCharacters(Character)
        case sameAsCurrentPassword
        
        var errorDescription: String? {
            switch self {
            case .tooShort:
                return "Password must be at least 12 characters long"
            case .tooLong:
                return "Password must not exceed 64 characters"
            case .missingUppercase:
                return "Password is missing a required uppercase letter"
            case .missingLowercase:
                return "Password is missing a required lowercase letter"
            case .missingNumber:
                return "Password is missing a required number"
            case .missingSpecialCharacter:
                return "Password is missing a required special character"
            case .multipleRequirements(let requirements):
                let missing = requirements.joined(separator: ", ")
                return "Password is missing a required \(missing)"
            case .keyboardPattern:
                return "Password contains a keyboard pattern (like 'qwerty' or 'asdfgh')"
            case .sequentialPattern(let pattern):
                return "Password contains a sequential pattern ('\(pattern)')"
            case .repeatedCharacters(let char):
                return "Password contains too many repeated characters ('\(char)')"
            case .sameAsCurrentPassword:
                return "New password must be different from current password"
            }
        }
    }
    
    /// Validates a password and returns a validation error if any rules are violated
    /// - Parameters:
    ///   - password: The password to validate
    ///   - currentPassword: Optional current password to check against (for password changes)
    /// - Returns: ValidationError if password is invalid, nil if valid
    static func validate(_ password: String, againstCurrentPassword currentPassword: String? = nil) -> ValidationError? {
        // Length checks
        if password.count < 12 {
            return .tooShort
        }
        
        if password.count > 64 {
            return .tooLong
        }
        
        // Complexity checks
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecialChar = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
        
        var missingRequirements: [String] = []
        if !hasUppercase { missingRequirements.append("uppercase letter") }
        if !hasLowercase { missingRequirements.append("lowercase letter") }
        if !hasNumber { missingRequirements.append("number") }
        if !hasSpecialChar { missingRequirements.append("special character") }
        
        if !missingRequirements.isEmpty {
            if missingRequirements.count == 1 {
                switch missingRequirements[0] {
                case "uppercase letter": return .missingUppercase
                case "lowercase letter": return .missingLowercase
                case "number": return .missingNumber
                case "special character": return .missingSpecialCharacter
                default: return .multipleRequirements(missingRequirements)
                }
            } else {
                return .multipleRequirements(missingRequirements)
            }
        }
        
        // Keyboard pattern check
        if let keyboardError = checkKeyboardPatterns(password) {
            return keyboardError
        }
        
        // Sequential pattern check
        if let sequentialError = checkSequentialPatterns(password) {
            return sequentialError
        }
        
        // Repeated character check
        if let repeatedError = checkRepeatedCharacters(password) {
            return repeatedError
        }
        
        // Check against current password if provided
        if let currentPassword = currentPassword, password == currentPassword {
            return .sameAsCurrentPassword
        }
        
        return nil
    }
    
    /// Validates a password and returns a user-friendly error message
    /// - Parameters:
    ///   - password: The password to validate
    ///   - currentPassword: Optional current password to check against
    /// - Returns: Error message string if invalid, nil if valid
    static func validateWithMessage(_ password: String, againstCurrentPassword currentPassword: String? = nil) -> String? {
        return validate(password, againstCurrentPassword: currentPassword)?.errorDescription
    }
    
    /// Checks if a password is valid (no validation errors)
    /// - Parameters:
    ///   - password: The password to validate
    ///   - currentPassword: Optional current password to check against
    /// - Returns: true if password is valid, false otherwise
    static func isValid(_ password: String, againstCurrentPassword currentPassword: String? = nil) -> Bool {
        return validate(password, againstCurrentPassword: currentPassword) == nil
    }
    
    // MARK: - Private Helper Methods
    
    private static func checkKeyboardPatterns(_ password: String) -> ValidationError? {
        let keyboardPattern = """
            (?:qwerty|asdfgh|zxcvbn|dvorak|qwertz|azerty|
            1qaz|2wsx|3edc|4rfv|5tgb|6yhn|7ujm|8ik|9ol|0p|
            zaq1|xsw2|cde3|vfr4|bgt5|nhy6|mju7|ki8|lo9|p0|
            qayz|wsxc|edcv|rfvb|tgbn|yhnm|ujm|ikol|polp)
            """
        
        if let regex = try? NSRegularExpression(pattern: keyboardPattern, options: [.allowCommentsAndWhitespace]),
           let match = regex.firstMatch(in: password.lowercased(), options: [], range: NSRange(location: 0, length: password.utf8.count)) {
            let matchedPattern = String(password.lowercased()[Range(match.range, in: password.lowercased())!])
            return .keyboardPattern(matchedPattern)
        }
        
        return nil
    }
    
    private static func checkSequentialPatterns(_ password: String) -> ValidationError? {
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
                
                if lowercasePassword.contains(forward) {
                    return .sequentialPattern(forward)
                }
                if lowercasePassword.contains(backward) {
                    return .sequentialPattern(backward)
                }
            }
        }
        
        return nil
    }
    
    private static func checkRepeatedCharacters(_ password: String) -> ValidationError? {
        let groups = Dictionary(grouping: password, by: { $0 })
        if let (char, _) = groups.first(where: { $0.value.count >= 3 }) {
            return .repeatedCharacters(char)
        }
        
        return nil
    }
} 