import Foundation
import Hummingbird

/// Response for availability check
struct AvailabilityResponse: Codable {
    let available: Bool
    let identifier: String
    let type: String
    
    init(available: Bool, identifier: String, type: String) {
        self.available = available
        self.identifier = identifier
        self.type = type
    }
}

extension AvailabilityResponse: ResponseEncodable {} 