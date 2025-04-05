import Foundation

/// Response for TOTP setup containing secret and QR code URL
public struct TOTPSetupResponse: Codable, Sendable {
    public let secret: String
    public let qrCodeUrl: String
    
    public init(secret: String, qrCodeUrl: String) {
        self.secret = secret
        self.qrCodeUrl = qrCodeUrl
    }
}

/// Response for TOTP status check
public struct TOTPStatusResponse: Codable, Sendable {
    public let totpMfaEnabled: Bool
    
    public init(totpMFAEnabled: Bool) {
        self.totpMfaEnabled = totpMFAEnabled
    }
} 