import Hummingbird

/// Response containing an error message, matching the application's standard error format
/// 
/// The format is consistent across all API endpoints:
/// ```json
/// {
///   "error": {
///     "message": "Error message description"
///   }
/// }
/// ```
/// Status codes are provided in the HTTP response, with appropriate headers like 
/// Retry-After for rate-limited responses (429).
struct ErrorResponse: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
    }
}

extension ErrorResponse: ResponseEncodable {} 
