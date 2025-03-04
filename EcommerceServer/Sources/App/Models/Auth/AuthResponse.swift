import Foundation
import Hummingbird

/// Response for successful login containing JWT token and user info
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: UInt
    let expiresAt: String
    let user: UserResponse
    let requiresTOTP: Bool
    
    init(accessToken: String, refreshToken: String, expiresIn: UInt, expiresAt: String, user: UserResponse, requiresTOTP: Bool = false) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
        self.user = user
        self.requiresTOTP = requiresTOTP
    }
}

extension AuthResponse: ResponseEncodable {} 
