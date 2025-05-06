import Foundation

/// Errors that can occur during TOTP operations
public enum TOTPError: LocalizedError  {
    case invalidCode
    case setupFailed
    case verificationFailed
    case alreadyEnabled
    case notEnabled
    case networkError(Error)
    case unknown(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidCode:
            return "Invalid verification code. Please try again."
        case .setupFailed:
            return "Failed to set up MFA. Please try again."
        case .verificationFailed:
            return "Verification failed. Please make sure you entered the correct code."
        case .alreadyEnabled:
            return "MFA is already enabled."
        case .notEnabled:
            return "MFA is not enabled."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

extension TOTPError: Equatable {
    public static func == (lhs: TOTPError, rhs: TOTPError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidCode, .invalidCode),
            (.setupFailed, .setupFailed),
            (.verificationFailed, .verificationFailed),
            (.alreadyEnabled, .alreadyEnabled),
            (.notEnabled, .notEnabled):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return (lhsError as NSError).domain == (rhsError as NSError).domain &&
            (lhsError as NSError).code == (rhsError as NSError).code
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return (lhsError as NSError).domain == (rhsError as NSError).domain &&
            (lhsError as NSError).code == (rhsError as NSError).code
        default:
            return false
        }
    }
}
