import Foundation

public enum AuthenticationError: LocalizedError {
    case noSignInInProgress
    case invalidTOTPToken
    case invalidCredentials
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case unknown
    case userCancelled
}

extension AuthenticationError: Equatable {
    public static func == (lhs: AuthenticationError, rhs: AuthenticationError) -> Bool {
        switch (lhs, rhs) {
        case (.noSignInInProgress, .noSignInInProgress),
             (.invalidTOTPToken, .invalidTOTPToken),
             (.invalidCredentials, .invalidCredentials),
             (.invalidResponse, .invalidResponse),
             (.unknown, .unknown),
             (.userCancelled, .userCancelled):
            return true
        case (.serverError(let lhsMessage), .serverError(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return String(describing: lhsError) == String(describing: rhsError)
        default:
            return false
        }
    }
}
