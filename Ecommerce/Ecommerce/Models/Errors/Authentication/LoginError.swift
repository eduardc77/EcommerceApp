import Foundation

public enum LoginError: LocalizedError, Equatable {
    case invalidCredentials
    case accountNotFound
    case accountLocked
    case tooManyAttempts
    case requiresMFA
    case networkError(String)
    case serverError(String)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountNotFound:
            return "No account found with this email"
        case .accountLocked:
            return "Your account has been locked. Please contact support"
        case .tooManyAttempts:
            return "Too many login attempts. Please try again later"
        case .requiresMFA:
            return "Multi-factor authentication is required"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknown(let message):
            return message
        }
    }
    
    public static func == (lhs: LoginError, rhs: LoginError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials),
             (.accountNotFound, .accountNotFound),
             (.accountLocked, .accountLocked),
             (.tooManyAttempts, .tooManyAttempts),
             (.requiresMFA, .requiresMFA):
            return true
        case (.networkError(let lhsMessage), .networkError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 