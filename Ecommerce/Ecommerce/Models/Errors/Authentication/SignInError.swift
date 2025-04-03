import Foundation

public enum SignInError: LocalizedError, Equatable {
    case invalidCredentials
    case accountLocked(retryAfter: Int?)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountLocked(let retryAfter):
            if let retryAfter = retryAfter {
                return "Too many sign in attempts. Please try again in \(retryAfter) seconds"
            }
            return "Too many sign in attempts. Please try again later"
        case .unknown(let message):
            return message
        }
    }
    
    public static func == (lhs: SignInError, rhs: SignInError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCredentials, .invalidCredentials):
            return true
        case (.accountLocked(let lhsRetry), .accountLocked(let rhsRetry)):
            return lhsRetry == rhsRetry
        case (.unknown(let lhsMessage), .unknown(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
} 
