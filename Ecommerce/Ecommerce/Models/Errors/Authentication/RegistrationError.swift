import Foundation

public enum RegistrationError: LocalizedError, Equatable {
    case weakPassword
    case invalidEmail
    case accountExists
    case termsNotAccepted
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .weakPassword:
            return "Password must be at least 8 characters and include a number and special character"
        case .invalidEmail:
            return "Please enter a valid email address"
        case .accountExists:
            return "An account with this email already exists"
        case .termsNotAccepted:
            return "You must accept the terms and conditions"
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
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 