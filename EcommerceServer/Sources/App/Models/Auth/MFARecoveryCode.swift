import Foundation
import FluentKit
import CryptoKit
import HummingbirdBcrypt

/// Errors specific to recovery code operations
enum RecoveryCodeError: Error {
    case invalidFormat
    case expired
    case tooManyAttempts
    case alreadyUsed
    case hashingFailed
    case secureRandomFailed
    
    var description: String {
        switch self {
        case .invalidFormat:
            return "Invalid recovery code format"
        case .expired:
            return "Recovery code has expired"
        case .tooManyAttempts:
            return "Too many failed attempts"
        case .alreadyUsed:
            return "Recovery code has already been used"
        case .hashingFailed:
            return "Failed to hash recovery code"
        case .secureRandomFailed:
            return "Failed to generate secure random data"
        }
    }
}

final class MFARecoveryCode: Model, @unchecked Sendable {
    static let schema = "mfa_recovery_codes"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "user_id")
    var user: User
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "used")
    var used: Bool
    
    @OptionalField(key: "used_at")
    var usedAt: Date?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    /// Number of failed attempts to use this code
    @Field(key: "failed_attempts")
    var failedAttempts: Int
    
    /// When this code expires (optional)
    @OptionalField(key: "expires_at")
    var expiresAt: Date?
    
    /// IP address where this code was used
    @OptionalField(key: "used_from_ip")
    var usedFromIP: String?
    
    /// User agent where this code was used
    @OptionalField(key: "used_from_user_agent")
    var usedFromUserAgent: String?
    
    init() { }
    
    init(id: UUID? = nil, userID: UUID, code: String, expiresAt: Date? = nil) {
        self.id = id
        self.$user.id = userID
        self.code = code
        self.used = false
        self.failedAttempts = 0
        self.expiresAt = expiresAt
    }
    
    /// Generate a set of recovery codes for a user
    /// - Parameter count: Number of recovery codes to generate (default: 10)
    /// - Returns: Array of generated recovery codes
    static func generateCodes(count: Int = 10) -> [String] {
        // Format: xxxx-xxxx-xxxx-xxxx where x is lowercase alphanumeric
        // This follows the format used by major providers like Auth0
        return (0..<count).map { _ in
            let groups = (0..<4).map { _ in
                String((0..<4).map { _ in Self.randomCharacter() })
            }
            return groups.joined(separator: "-")
        }
    }
    
    /// Mark this recovery code as used
    func markAsUsed(fromIP: String?, userAgent: String?) {
        self.used = true
        self.usedAt = Date()
        self.usedFromIP = fromIP
        self.usedFromUserAgent = userAgent
    }
    
    /// Increment failed attempts counter
    func incrementFailedAttempts() {
        self.failedAttempts += 1
    }
    
    /// Check if the code is expired
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }
    
    /// Check if too many failed attempts
    var hasExceededAttempts: Bool {
        return failedAttempts >= 5  // Industry standard is typically 3-5 attempts
    }
    
    /// Generate a random alphanumeric character
    private static func randomCharacter() -> Character {
        // Use only lowercase letters and numbers (industry standard)
        let characters = "0123456789abcdefghijklmnopqrstuvwxyz"
        var generator = SystemRandomNumberGenerator()
        let index = Int.random(in: 0..<characters.count, using: &generator)
        return characters[characters.index(characters.startIndex, offsetBy: index)]
    }
    
    /// Hash a recovery code for secure storage
    /// - Parameter code: The recovery code to hash
    /// - Returns: Hashed recovery code
    /// - Throws: RecoveryCodeError if hashing fails
    static func hashCode(_ code: String) throws -> String {
        // Validate format first
        let pattern = "^[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}-[0-9a-z]{4}$"
        guard code.range(of: pattern, options: .regularExpression) != nil else {
            throw RecoveryCodeError.invalidFormat
        }
        
        // Normalize the code by removing hyphens and converting to lowercase
        let normalized = code.lowercased().replacingOccurrences(of: "-", with: "")
        
        // Use Bcrypt for hashing (same as password hashing)
        let hashedCode = Bcrypt.hash(normalized, cost: 12)
        return hashedCode
    }
    
    /// Verify a recovery code
    /// - Parameter code: The code to verify
    /// - Returns: True if the code matches and is valid
    /// - Throws: RecoveryCodeError if validation fails
    func verifyCode(_ code: String) throws -> Bool {
        // Check if already used
        if used {
            throw RecoveryCodeError.alreadyUsed
        }
        
        // Check if code is expired
        if isExpired {
            throw RecoveryCodeError.expired
        }
        
        // Check if too many failed attempts
        if hasExceededAttempts {
            throw RecoveryCodeError.tooManyAttempts
        }
        
        // Normalize and verify the code
        let normalized = code.lowercased().replacingOccurrences(of: "-", with: "")
        return Bcrypt.verify(normalized, hash: self.code)
    }
} 
