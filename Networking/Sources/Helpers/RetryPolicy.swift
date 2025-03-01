import Foundation

public protocol RetryPolicy: Sendable {
    func shouldRetry(error: Error, attempt: Int) -> Bool
    func retryDelay(for attempt: Int) -> TimeInterval
}

public struct DefaultRetryPolicy: RetryPolicy {
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    
    public init(maxAttempts: Int = 3, baseDelay: TimeInterval = 1.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
    }
    
    public func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        switch error {
        case let networkError as NetworkError:
            switch networkError {
            case .timeout, .serverError:
                return true
            default:
                return false
            }
        default:
            return false
        }
    }
    
    public func retryDelay(for attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^attempt
        return baseDelay * pow(2.0, Double(attempt))
    }
}
