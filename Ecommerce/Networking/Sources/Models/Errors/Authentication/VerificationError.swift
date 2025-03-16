import Foundation

public enum VerificationError: LocalizedError {
    case invalidCode
    case expiredCode
    case tooManyAttempts
    case emailNotFound
    case alreadyVerified
    case tooManyRequests
    case unknown(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid verification code"
        case .expiredCode:
            return "This code has expired. Please request a new one"
        case .tooManyAttempts:
            return "Too many invalid attempts. Please request a new code"
        case .emailNotFound:
            return "Email address not found"
        case .alreadyVerified:
            return "This email is already verified"
        case .tooManyRequests:
            return "Too many requests. Please try again later"
        case .unknown(let message):
            return message
        }
    }
} 