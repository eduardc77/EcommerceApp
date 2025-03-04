import Foundation
import HummingbirdOTP

/// Utility functions for TOTP (Time-based One-Time Password) operations
enum TOTPUtils {
    /// Verify a TOTP code against a secret
    /// - Parameters:
    ///   - code: The code to verify
    ///   - secret: The secret key
    /// - Returns: True if the code is valid, false otherwise
    static func verifyTOTPCode(code: String, secret: String) -> Bool {
        guard let codeInt = Int(code) else {
            return false
        }
        let totp = TOTP(secret: secret)
        let now = Date.now
        let computedTOTP = totp.compute(date: now - 15.0)
        let computedTOTP2 = totp.compute(date: now + 15.0)
        
        return codeInt == computedTOTP || codeInt == computedTOTP2
    }

    /// Generate a new TOTP secret
    /// - Returns: A UUID string to be used as the secret
    static func generateSecret() -> String {
        UUID().uuidString
    }
    
    /// Generate QR code URL for TOTP setup
    /// - Parameters:
    ///   - secret: The TOTP secret
    ///   - label: The label for the authenticator app (usually email or username)
    ///   - issuer: The name of the app/service
    /// - Returns: URL string for QR code
    static func generateQRCodeURL(secret: String, label: String, issuer: String) -> String {
        let totp = TOTP(secret: secret)
        return totp.createAuthenticatorURL(label: label)
    }
}
