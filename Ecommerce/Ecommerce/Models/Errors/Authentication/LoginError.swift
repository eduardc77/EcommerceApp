import Foundation

public enum LoginError: LocalizedError, Equatable {
    case invalidCredentials
    case accountNotFound
    case accountLocked(retryAfter: Int?)
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
            return "Invalid email or password"
        case .accountLocked(let retryAfter):
            if let seconds = retryAfter {
                let minutes = Int(ceil(Double(seconds) / 60.0))
                return "Too many failed attempts. Please try again in \(minutes) minute\(minutes == 1 ? "" : "s")"
            }
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
             (.tooManyAttempts, .tooManyAttempts),
             (.requiresMFA, .requiresMFA):
            return true
        case (.accountLocked(let lhsRetry), .accountLocked(let rhsRetry)):
            return lhsRetry == rhsRetry
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
