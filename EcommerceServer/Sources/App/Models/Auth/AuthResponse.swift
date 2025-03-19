import Foundation
import Hummingbird

/// Response for successful login containing JWT token and user info
struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: UInt
    let expiresAt: String
    let user: UserResponse
    let requiresTOTP: Bool
    let requiresEmailVerification: Bool
    let tempToken: String?
    
    init(
        accessToken: String,
        refreshToken: String,
        tokenType: String = "Bearer",
        expiresIn: UInt,
        expiresAt: String,
        user: UserResponse,
        requiresTOTP: Bool = false,
        requiresEmailVerification: Bool = false,
        tempToken: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresIn = expiresIn
        self.expiresAt = expiresAt
        self.user = user
        self.requiresTOTP = requiresTOTP
        self.requiresEmailVerification = requiresEmailVerification
        self.tempToken = tempToken
    }
}

extension AuthResponse: ResponseEncodable {} 
