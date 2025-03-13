import Foundation

/// Response for password validation feedback
public struct PasswordValidationResponse: Codable, Sendable {
    public let isValid: Bool
    public let errors: [String]
    public let strength: String
    public let strengthColor: String
    public let suggestions: [String]
    
    public init(
        isValid: Bool,
        errors: [String],
        strength: String,
        strengthColor: String,
        suggestions: [String]
    ) {
        self.isValid = isValid
        self.errors = errors
        self.strength = strength
        self.strengthColor = strengthColor
        self.suggestions = suggestions
    }
} 