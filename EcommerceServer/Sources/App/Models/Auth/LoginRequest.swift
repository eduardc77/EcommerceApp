import Foundation

/// Request for sign in
struct SignInRequest: Decodable {
    let identifier: String
    let password: String
    let totpCode: String?
    
    enum CodingKeys: String, CodingKey {
        case identifier = "email" // Keep "email" as the key for backward compatibility
        case password
        case totpCode
    }
} 