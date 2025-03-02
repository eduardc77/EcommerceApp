import Foundation
import Hummingbird

/// Response for successful login containing JWT token and user info
struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: UInt
    let expiresAt: String
    let user: UserResponse
}

extension AuthResponse: ResponseEncodable {} 
