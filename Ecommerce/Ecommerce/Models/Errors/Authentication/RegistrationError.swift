import Foundation

public enum RegistrationError: LocalizedError, Equatable {
    case weakPassword
    case invalidEmail
    case accountExists
    case termsNotAccepted
    case validationError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .weakPassword:
            return "Password must be at least 8 characters and include a number and special character"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .accountExists:
            return "An account with this email or username already exists"
        case .termsNotAccepted:
            return "You must accept the terms and conditions"
        case .validationError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
    
    public static func == (lhs: RegistrationError, rhs: RegistrationError) -> Bool {
        switch (lhs, rhs) {
        case (.weakPassword, .weakPassword),
             (.invalidEmail, .invalidEmail),
             (.accountExists, .accountExists),
             (.termsNotAccepted, .termsNotAccepted):
            return true
        case (.validationError(let lhsMessage), .validationError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 