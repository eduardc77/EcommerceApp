import Foundation
import CryptoKit
import Logging

/// Represents different types of password validation errors
enum PasswordValidationError: Error, Equatable, CustomStringConvertible {
    case tooShort(minimum: Int)
    case tooLong(maximum: Int)
    case containsCommonPassword
    case containsPersonalInfo(field: String)
    case containsRepeatedCharacters(char: Character)
    case containsSequentialPattern(pattern: String)
    case containsKeyboardPattern
    case invalidUnicode
    case insufficientEntropy(current: Double, required: Double)
    case missingRequiredCharacter(type: String)
    
    var description: String {
        switch self {
        case .tooShort(let min):
            return "Password must be at least \(min) characters long"
        case .tooLong(let max):
            return "Password must not exceed \(max) characters"
        case .containsCommonPassword:
            return "This password appears in a list of commonly used passwords. Please choose a different one"
        case .containsPersonalInfo(let field):
            return "Password should not contain your \(field)"
        case .containsRepeatedCharacters(let char):
            return "Password contains too many repeated characters ('\(char)')"
        case .containsSequentialPattern(let pattern):
            return "Password contains a sequential pattern ('\(pattern)')"
        case .containsKeyboardPattern:
            return "Password contains a keyboard pattern (like 'qwerty' or 'asdfgh')"
        case .invalidUnicode:
            return "Password contains invalid Unicode characters"
        case .insufficientEntropy(let current, let required):
            return "Password is not complex enough (entropy: \(String(format: "%.1f", current)) bits, required: \(String(format: "%.1f", required)) bits)"
        case .missingRequiredCharacter(let type):
            return "Password is missing a required \(type)"
        }
    }
}

/// Password strength level
enum PasswordStrength: Int, Comparable {
    case veryWeak = 0
    case weak = 1
    case moderate = 2
    case strong = 3
    case veryStrong = 4
    
    var description: String {
        switch self {
        case .veryWeak: return "Very Weak"
        case .weak: return "Weak"
        case .moderate: return "Moderate"
        case .strong: return "Strong"
        case .veryStrong: return "Very Strong"
        }
    }
    
    var color: String {
        switch self {
        case .veryWeak: return "#FF0000"  // Red
        case .weak: return "#FF6B00"      // Orange
        case .moderate: return "#FFD700"   // Yellow
        case .strong: return "#7CBA3D"     // Light Green
        case .veryStrong: return "#00A550" // Dark Green
        }
    }
    
    static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Password validation result
struct PasswordValidationResult {
    let isValid: Bool
    let errors: [PasswordValidationError]
    let strength: PasswordStrength
    let suggestions: [String]
    let entropy: Double
    
    var firstError: String? {
        errors.first?.description
    }
    
    var allErrors: [String] {
        errors.map { $0.description }
    }
}

struct PasswordValidator {
    private let config: JWTConfiguration
    private let minimumEntropy: Double = 40.0 // NIST recommends at least 30-40 bits of entropy
    private let logger: Logger
    
    // Instead of a static set, use a cryptographic hash of common passwords
    // This prevents the common passwords from being visible in the code
    private static let commonPasswordHashes: Set<String> = {
        let commonPasswords = [
            "password", "123456", "12345678", "qwerty", "abc123",
            // ... reduced list for brevity ...
        ]
        return Set(commonPasswords.map { password in
            let data = Data(password.utf8)
            let hashed = SHA256.hash(data: data)
            return hashed.compactMap { String(format: "%02x", $0) }.joined()
        })
    }()
    
    // Modern keyboard pattern detection using regex
    private static let keyboardPatternRegex = try! NSRegularExpression(pattern: """
        (?:qwerty|asdfgh|zxcvbn|dvorak|qwertz|azerty|
        1qaz|2wsx|3edc|4rfv|5tgb|6yhn|7ujm|8ik|9ol|0p|
        zaq1|xsw2|cde3|vfr4|bgt5|nhy6|mju7|ki8|lo9|p0|
        qayz|wsxc|edcv|rfvb|tgbn|yhnm|ujm|ikol|polp)
        """, options: [.allowCommentsAndWhitespace])
    
    // Enhanced sequential pattern detection
    private static let sequentialPatterns = [
        Array("abcdefghijklmnopqrstuvwxyz"),
        Array("0123456789"),
        Array("qwertyuiop"),
        Array("asdfghjkl"),
        Array("zxcvbnm")
    ]
    
    init(config: JWTConfiguration = .load(), logger: Logger? = nil) {
        self.config = config
        self.logger = logger ?? Logger(label: "app.password-validator")
    }
    
    func validate(_ password: String, userInfo: [String: String] = [:]) -> PasswordValidationResult {
        var errors: [PasswordValidationError] = []
        var suggestions: [String] = []
        
        logger.debug("Starting password validation")
        
        // Normalize Unicode characters using NFKC normalization
        guard let normalizedData = password.data(using: .utf8),
              let normalizedPassword = String(data: normalizedData, encoding: .utf8)?.precomposedStringWithCompatibilityMapping else {
            errors.append(.invalidUnicode)
            logger.debug("Failed Unicode normalization")
            return PasswordValidationResult(
                isValid: false,
                errors: errors,
                strength: .veryWeak,
                suggestions: ["Please use valid text characters"],
                entropy: 0
            )
        }
        
        logger.debug("Password length: \(normalizedPassword.count)")
        
        // Check length (NIST SP 800-63B guidelines)
        if normalizedPassword.count < config.minimumPasswordLength {
            logger.debug("Password too short. Min required: \(config.minimumPasswordLength)")
            errors.append(.tooShort(minimum: config.minimumPasswordLength))
            suggestions.append("Use a memorable passphrase instead of a single word")
        }
        if normalizedPassword.count > config.maximumPasswordLength {
            logger.debug("Password too long. Max allowed: \(config.maximumPasswordLength)")
            errors.append(.tooLong(maximum: config.maximumPasswordLength))
        }

        // Add strict character type requirements
        if !normalizedPassword.contains(where: { $0.isUppercase }) {
            errors.append(.missingRequiredCharacter(type: "uppercase letter"))
            suggestions.append("Add at least one uppercase letter")
        }
        if !normalizedPassword.contains(where: { $0.isNumber }) {
            errors.append(.missingRequiredCharacter(type: "number"))
            suggestions.append("Add at least one number")
        }
        if !normalizedPassword.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) {
            errors.append(.missingRequiredCharacter(type: "special character"))
            suggestions.append("Add at least one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)")
        }
        
        let lowercasePassword = normalizedPassword.lowercased()
        
        // Check for common passwords using hash comparison
        let passwordHash = SHA256.hash(data: Data(lowercasePassword.utf8))
            .compactMap { String(format: "%02x", $0) }
            .joined()
        
        if Self.commonPasswordHashes.contains(passwordHash) {
            logger.debug("Password found in common passwords list")
            errors.append(.containsCommonPassword)
            suggestions.append("Use a unique password that hasn't appeared in data breaches")
        }
        
        // Enhanced personal information check
        checkPersonalInfo(normalizedPassword, userInfo: userInfo, errors: &errors, suggestions: &suggestions)
        
        // Check for repeated characters with better pattern detection
        checkRepeatedCharacters(normalizedPassword, errors: &errors, suggestions: &suggestions)
        
        // Enhanced sequential pattern check
        checkSequentialPatterns(lowercasePassword, errors: &errors, suggestions: &suggestions)
        
        // Calculate entropy and strength
        let (strength, entropy) = calculateStrengthAndEntropy(password: normalizedPassword)
        logger.debug("Password entropy: \(entropy) bits")
        
        // Check minimum entropy requirement
        if entropy < minimumEntropy {
            logger.debug("Insufficient entropy. Required: \(minimumEntropy) bits")
            errors.append(.insufficientEntropy(current: entropy, required: minimumEntropy))
        }
        
        // Add contextual suggestions based on validation results
        if strength < .strong {
            suggestions.append(contentsOf: [
                "Consider using a passphrase: multiple random words combined",
                "Add unique character combinations",
                "Make it longer while keeping it memorable"
            ])
        }
        
        logger.debug("Validation complete. Valid: \(errors.isEmpty && entropy >= minimumEntropy)")
        
        return PasswordValidationResult(
            isValid: errors.isEmpty && entropy >= minimumEntropy,
            errors: errors,
            strength: strength,
            suggestions: Array(Set(suggestions)),  // Remove duplicates
            entropy: entropy
        )
    }
    
    private func checkPersonalInfo(_ password: String, userInfo: [String: String], errors: inout [PasswordValidationError], suggestions: inout [String]) {
        let lowercasePassword = password.lowercased()
        for (field, value) in userInfo {
            if !value.isEmpty {
                // Check for variations of personal info
                let variations = generateVariations(of: value)
                for variation in variations {
                    if lowercasePassword.contains(variation.lowercased()) {
                        errors.append(.containsPersonalInfo(field: field))
                        suggestions.append("Avoid using any personal information that others might know")
                        return
                    }
                }
            }
        }
    }
    
    private func generateVariations(of text: String) -> Set<String> {
        var variations = Set([text])
        let lowercased = text.lowercased()
        variations.insert(lowercased)
        variations.insert(lowercased.replacingOccurrences(of: "a", with: "@"))
        variations.insert(lowercased.replacingOccurrences(of: "i", with: "1"))
        variations.insert(lowercased.replacingOccurrences(of: "o", with: "0"))
        variations.insert(lowercased.replacingOccurrences(of: "e", with: "3"))
        return variations
    }
    
    private func checkRepeatedCharacters(_ password: String, errors: inout [PasswordValidationError], suggestions: inout [String]) {
        var charCount: [Character: Int] = [:]
        for char in password {
            charCount[char, default: 0] += 1
            if charCount[char]! >= 3 {
                errors.append(.containsRepeatedCharacters(char: char))
                suggestions.append("Avoid repeating the same character multiple times")
                return
            }
        }
    }
    
    private func checkSequentialPatterns(_ password: String, errors: inout [PasswordValidationError], suggestions: inout [String]) {
        // Check for keyboard patterns
        let range = NSRange(location: 0, length: password.utf16.count)
        if Self.keyboardPatternRegex.firstMatch(in: password, options: [], range: range) != nil {
            errors.append(.containsKeyboardPattern)
            suggestions.append("Avoid using keyboard patterns")
            return
        }
        
        // Check for sequential patterns
        for pattern in Self.sequentialPatterns {
            let patternLength = 3 // Minimum length to consider as a pattern
            for i in 0...(pattern.count - patternLength) {
                let slice = pattern[i..<(i + patternLength)]
                let forward = String(slice)
                let backward = String(slice.reversed())
                
                if password.contains(forward) || password.contains(backward) {
                    errors.append(.containsSequentialPattern(pattern: forward))
                    suggestions.append("Avoid using sequential patterns")
                    return
                }
            }
        }
    }
    
    private func calculateStrengthAndEntropy(password: String) -> (PasswordStrength, Double) {
        var entropy = 0.0
        
        // Calculate character set entropy
        var charSets = 0
        if password.contains(where: { $0.isLowercase }) { charSets += 26 }
        if password.contains(where: { $0.isUppercase }) { charSets += 26 }
        if password.contains(where: { $0.isNumber }) { charSets += 10 }
        if password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) }) { charSets += 32 }
        
        // Basic entropy calculation
        entropy = log2(Double(charSets)) * Double(password.count)
        
        // Adjust for unique characters (more unique = higher entropy)
        let uniqueChars = Double(Set(password).count)
        entropy *= (uniqueChars / Double(password.count) + 0.5) // Bonus for uniqueness
        
        // Adjust for patterns and repetitions
        if password.range(of: #"(.)\1{2,}"#, options: .regularExpression) != nil {
            entropy *= 0.8 // Penalty for repetitions
        }
        
        // Determine strength based on entropy
        let strength: PasswordStrength
        switch entropy {
        case ..<20:
            strength = .veryWeak
        case 20..<40:
            strength = .weak
        case 40..<60:
            strength = .moderate
        case 60..<80:
            strength = .strong
        default:
            strength = .veryStrong
        }
        
        return (strength, entropy)
    }
} 