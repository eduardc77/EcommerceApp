import Foundation
import Hummingbird

/// Response containing an error message, matching Hummingbird's error format
struct ErrorResponse: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
    }
}

extension ErrorResponse: ResponseEncodable {} 