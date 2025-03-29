import Foundation
import Hummingbird

/// Base request for social sign in via Google or Apple
struct SocialSignInRequest: Codable {
    /// The provider for this social sign in (google, apple)
    let provider: String
    
    /// Provider-specific parameters
    let parameters: SocialLoginParameters
    
    enum CodingKeys: String, CodingKey {
        case provider
        case parameters
    }
}

/// Provider-specific parameters needed for social sign in
enum SocialLoginParameters: Codable {
    /// Google authentication parameters
    case google(GoogleAuthParams)
    
    /// Apple authentication parameters
    case apple(AppleAuthParams)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "google":
            self = .google(try container.decode(GoogleAuthParams.self, forKey: .data))
        case "apple":
            self = .apple(try container.decode(AppleAuthParams.self, forKey: .data))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown social sign in parameter type: \(type)"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .google(let params):
            try container.encode("google", forKey: .type)
            try container.encode(params, forKey: .data)
        case .apple(let params):
            try container.encode("apple", forKey: .type)
            try container.encode(params, forKey: .data)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
}

/// Google-specific authentication parameters
struct GoogleAuthParams: Codable {
    /// Token ID received from Google authentication
    let idToken: String
    
    /// Access token received from Google authentication (optional)
    let accessToken: String?
}

/// Apple-specific authentication parameters
struct AppleAuthParams: Codable {
    /// The identity token received from Sign in with Apple
    let identityToken: String
    
    /// The authorization code received from Sign in with Apple
    let authorizationCode: String
    
    /// User's full name from Apple (may be null for returning users)
    let fullName: AppleNameComponents?
    
    /// User's email from Apple (may be null for returning users)
    let email: String?
}

/// Apple name components structure
struct AppleNameComponents: Codable {
    let givenName: String?
    let familyName: String?
    
    var displayName: String? {
        [givenName, familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .isEmpty ? nil : [givenName, familyName]
                .compactMap { $0 }
                .joined(separator: " ")
    }
} 
