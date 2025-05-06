import Foundation

public enum SignInError: LocalizedError {
    case invalidCredentials
    case accountLocked(retryAfter: Int?)
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .accountLocked(let retryAfter):
            if let retryAfter = retryAfter {
                let minutes = Int(ceil(Double(retryAfter) / 60.0))
                return "Too many sign in attempts. Please try again in \(minutes) minute\(minutes == 1 ? "" : "s")"
            }
            return "Too many sign in attempts. Please try again later"
        case .unknown(let message):
            return message
        }
    }
}

extension SignInError: Equatable {
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
