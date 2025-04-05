import Foundation
import Hummingbird
import HummingbirdBasicAuth
import HummingbirdBcrypt
import FluentKit

/// Database description of a user
final class User: Model, PasswordAuthenticatable, @unchecked Sendable {
    static let schema = "user"
    
    /// Domain used for SSO/JWT-created users
    static let ssoEmailDomain = "sso.internal"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "username")
    var username: String
    
    @Field(key: "display_name")
    var displayName: String
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "profile_picture")
    var profilePicture: String?
    
    @Enum(key: "role")
    var role: Role
    
    @OptionalField(key: "password_hash")
    var passwordHash: String?
    
    @OptionalField(key: "password_updated_at")
    var passwordUpdatedAt: Date?
    
    @Field(key: "email_verified")
    var emailVerified: Bool
    
    @Field(key: "failed_sign_in_attempts")
    var failedSignInAttempts: Int
    
    @OptionalField(key: "last_failed_sign_in")
    var lastFailedSignIn: Date?
    
    @OptionalField(key: "last_sign_in_at")
    var lastSignInAt: Date?
    
    @Field(key: "account_locked")
    var accountLocked: Bool
    
    @OptionalField(key: "lockout_until")
    var lockoutUntil: Date?
    
    @Field(key: "require_password_change")
    var requirePasswordChange: Bool
    
    @Field(key: "totp_mfa_enabled")
    var totpMFAEnabled: Bool
    
    @OptionalField(key: "totp_mfa_secret")
    var totpMFASecret: String?
    
    @Field(key: "email_mfa_enabled")
    var emailMFAEnabled: Bool
    
    @OptionalField(key: "password_history")
    var passwordHistory: [String]?
    
    @Field(key: "token_version")
    var tokenVersion: Int
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Maximum number of password history entries to keep
    internal static let maxPasswordHistoryCount = 10
    
    /// Maximum number of concurrent sessions allowed
    private static let maxConcurrentSessions = 5
    
    init() {}
    
    init(
        id: UUID? = nil,
        username: String,
        displayName: String,
        email: String,
        profilePicture: String? = nil,
        role: Role = .customer,
        passwordHash: String?,
        emailVerified: Bool = false,
        failedSignInAttempts: Int = 0,
        lastFailedSignIn: Date? = nil,
        lastSignInAt: Date? = nil,
        accountLocked: Bool = false,
        lockoutUntil: Date? = nil,
        requirePasswordChange: Bool = false,
        totpMFAEnabled: Bool = false,
        totpMFASecret: String? = nil,
        emailMFAEnabled: Bool = false,
        passwordUpdatedAt: Date? = nil,
        passwordHistory: [String]? = nil,
        tokenVersion: Int = 0
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.profilePicture = profilePicture
        self.role = role
        self.passwordHash = passwordHash
        self.emailVerified = emailVerified
        self.failedSignInAttempts = failedSignInAttempts
        self.lastFailedSignIn = lastFailedSignIn
        self.lastSignInAt = lastSignInAt
        self.accountLocked = accountLocked
        self.lockoutUntil = lockoutUntil
        self.requirePasswordChange = requirePasswordChange
        self.totpMFAEnabled = totpMFAEnabled
        self.totpMFASecret = totpMFASecret
        self.emailMFAEnabled = emailMFAEnabled
        self.passwordUpdatedAt = passwordUpdatedAt
        self.passwordHistory = passwordHistory
        self.tokenVersion = tokenVersion
    }
    
    /// Initialize a user from SSO/JWT
    init(fromSSO name: String, id: UUID? = nil) {
        self.id = id
        self.username = name
        self.displayName = name
        self.email = Self.createSSOEmail(for: name)
        self.profilePicture = nil
        self.role = .customer
        self.passwordHash = nil
        self.emailVerified = true
        self.failedSignInAttempts = 0
        self.lastFailedSignIn = nil
        self.lastSignInAt = nil
        self.accountLocked = false
        self.lockoutUntil = nil
        self.requirePasswordChange = false
        self.totpMFAEnabled = false
        self.totpMFASecret = nil
        self.emailMFAEnabled = false
        self.passwordUpdatedAt = nil
        self.passwordHistory = nil
        self.tokenVersion = 0
    }
    
    /// Validate password against security requirements
    static func validatePassword(_ password: String, userInfo: [String: String] = [:]) throws {
        let validator = PasswordValidator()
        let result = validator.validate(password, userInfo: userInfo)
        
        if !result.isValid {
            // Throw the first error if any
            if let errorMessage = result.firstError {
                throw HTTPError(.badRequest, message: errorMessage)
            } else {
                throw HTTPError(.badRequest, message: "Invalid password")
            }
        }
    }
    
    init(from userRequest: SignUpRequest) async throws {
        // Validate password first with user info for better validation
        try Self.validatePassword(userRequest.password, userInfo: [
            "username": userRequest.username,
            "email": userRequest.email
        ])
        
        self.id = nil
        self.username = userRequest.username
        self.displayName = userRequest.displayName
        self.email = userRequest.email
        self.profilePicture = userRequest.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = .customer  // Default role for public registration
        self.emailVerified = false
        self.failedSignInAttempts = 0
        self.lastFailedSignIn = nil
        self.lastSignInAt = nil
        self.accountLocked = false
        self.lockoutUntil = nil
        self.requirePasswordChange = false
        self.totpMFAEnabled = false
        self.totpMFASecret = nil
        self.emailMFAEnabled = false
        
        // Hash the password
        let passwordHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(userRequest.password, cost: 12)
        }
        self.passwordHash = passwordHash
        self.passwordUpdatedAt = Date()
        
        // Store the initial password hash in history
        self.passwordHistory = [passwordHash]
        
        self.tokenVersion = 0
    }
    
    init(from adminRequest: AdminCreateUserRequest) async throws {
        // Validate password first with user info for better validation
        try Self.validatePassword(adminRequest.password, userInfo: [
            "username": adminRequest.username,
            "email": adminRequest.email
        ])
        
        self.id = nil
        self.username = adminRequest.username
        self.displayName = adminRequest.displayName
        self.email = adminRequest.email
        self.profilePicture = adminRequest.profilePicture ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = adminRequest.role  // Use specified role for admin creation
        self.emailVerified = false
        self.failedSignInAttempts = 0
        self.lastFailedSignIn = nil
        self.lastSignInAt = nil
        self.accountLocked = false
        self.lockoutUntil = nil
        self.requirePasswordChange = false
        self.totpMFAEnabled = false
        self.totpMFASecret = nil
        self.emailMFAEnabled = false
        
        // Hash the password
        let passwordHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(adminRequest.password, cost: 12)
        }
        self.passwordHash = passwordHash
        self.passwordUpdatedAt = Date()
        
        // Store the initial password hash in history
        self.passwordHistory = [passwordHash]
        
        self.tokenVersion = 0
    }
    
    /// Create an SSO email address for a user
    static func createSSOEmail(for username: String) -> String {
        return "\(username)@\(ssoEmailDomain)"
    }
    
    func incrementFailedSignInAttempts() {
        self.failedSignInAttempts += 1
        self.lastFailedSignIn = Date()
        
        // Auto-lock account after too many failed attempts
        if self.failedSignInAttempts >= 5 {
            self.accountLocked = true
            self.lockoutUntil = Date().addingTimeInterval(15 * 60) // 15 minutes
        }
    }
    
    func resetFailedSignInAttempts() {
        self.failedSignInAttempts = 0
        self.lastFailedSignIn = nil
        self.accountLocked = false
        self.lockoutUntil = nil
    }
    
    func updateLastSignIn() {
        self.lastSignInAt = Date()
    }
    
    func isLocked() -> Bool {
        if !accountLocked { return false }
        if let lockoutUntil = lockoutUntil, Date() > lockoutUntil {
            // Auto-unlock if lockout period has passed
            accountLocked = false
            return false
        }
        return accountLocked
    }
    
    /// Check if a password has been used before
    /// - Parameter password: The password to check
    /// - Returns: True if the password has been used before, false otherwise
    func isPasswordPreviouslyUsed(_ password: String) async throws -> Bool {
        guard let history = passwordHistory else { return false }
        
        for historicHash in history {
            if try await NIOThreadPool.singleton.runIfActive({
                Bcrypt.verify(password, hash: historicHash)
            }) {
                return true
            }
        }
        return false
    }
    
    /// Update password and maintain password history
    /// - Parameter newPassword: The new password to set
    func updatePassword(_ newPassword: String) async throws {
        // Check if password was previously used
        if try await isPasswordPreviouslyUsed(newPassword) {
            throw HTTPError(.badRequest, message: "Password has been used before. Please choose a different password.")
        }
        
        // Hash the new password with increased cost factor for better security
        let newHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(newPassword, cost: 12)  // Increased from default
        }
        
        // If there's an existing password hash, add it to history
        if let currentHash = passwordHash {
            var history = passwordHistory ?? []
            history.insert(currentHash, at: 0)
            
            // Keep only the most recent passwords
            if history.count > Self.maxPasswordHistoryCount {
                history = Array(history.prefix(Self.maxPasswordHistoryCount))
            }
            
            passwordHistory = history
        }
        
        // Update the password hash and timestamp
        passwordHash = newHash
        passwordUpdatedAt = Date()
        
        // Increment token version to invalidate all existing sessions
        tokenVersion += 1
    }
    
    /// Sanitize username by removing unwanted characters
    private static func sanitizeUsername(_ username: String) -> String {
        // Remove any characters that aren't alphanumeric or certain special chars
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._@")
        return String(username.unicodeScalars.filter { allowedCharacters.contains($0) })
    }
    
    /// Validate profilePicture URL
    private static func validateProfilePictureURL(_ url: String?) -> String? {
        guard let url = url else { return nil }
        
        // Only allow HTTPS URLs
        guard url.lowercased().hasPrefix("https://") else {
            return "https://api.dicebear.com/7.x/avataaars/png"
        }
        
        // Validate URL format
        guard URL(string: url) != nil else {
            return "https://api.dicebear.com/7.x/avataaars/png"
        }
        
        return url
    }
    
    /// Verify a TOTP code for this user
    /// - Parameter code: The TOTP code to verify
    /// - Returns: True if the code is valid, false otherwise
    func verifyTOTPCode(_ code: String) async throws -> Bool {
        guard let secret = totpMFASecret else {
            throw HTTPError(.internalServerError, message: "MFA is not properly configured")
        }
        
        return TOTPUtils.verifyTOTPCode(code: code, secret: secret)
    }
}

extension User {
    enum FieldKey {
        static let username: FluentKit.FieldKey = "username"
        static let displayName: FluentKit.FieldKey = "display_name"
        static let email: FluentKit.FieldKey = "email"
        static let profilePicture: FluentKit.FieldKey = "profile_picture"
        static let role: FluentKit.FieldKey = "role"
        static let passwordHash: FluentKit.FieldKey = "password_hash"
        static let passwordUpdatedAt: FluentKit.FieldKey = "password_updated_at"
        static let emailVerified: FluentKit.FieldKey = "email_verified"
        static let failedSignInAttempts: FluentKit.FieldKey = "failed_sign_in_attempts"
        static let lastFailedSignIn: FluentKit.FieldKey = "last_failed_sign_in"
        static let lastSignInAt: FluentKit.FieldKey = "last_sign_in_at"
        static let accountLocked: FluentKit.FieldKey = "account_locked"
        static let lockoutUntil: FluentKit.FieldKey = "lockout_until"
        static let requirePasswordChange: FluentKit.FieldKey = "require_password_change"
        static let totpMFAEnabled: FluentKit.FieldKey = "totp_mfa_enabled"
        static let totpMFASecret: FluentKit.FieldKey = "totp_mfa_secret"
        static let emailMFAEnabled: FluentKit.FieldKey = "email_mfa_enabled"
        static let passwordHistory: FluentKit.FieldKey = "password_history"
        static let tokenVersion: FluentKit.FieldKey = "token_version"
        static let createdAt: FluentKit.FieldKey = "created_at"
        static let updatedAt: FluentKit.FieldKey = "updated_at"
    }
}

// MARK: - Migration
extension User {
    struct Migration: AsyncMigration {
        func prepare(on database: Database) async throws {
            try await database.schema(User.schema)
                .id()
                .field(FieldKey.username, .string, .required)
                .unique(on: FieldKey.username)
                .field(FieldKey.displayName, .string, .required)
                .field(FieldKey.email, .string, .required)
                .unique(on: FieldKey.email)
                .field(FieldKey.profilePicture, .string)
                .field(FieldKey.role, .string, .required)
                .field(FieldKey.passwordHash, .string)
                .field(FieldKey.passwordUpdatedAt, .datetime)
                .field(FieldKey.emailVerified, .bool, .required)
                .field(FieldKey.failedSignInAttempts, .int, .required)
                .field(FieldKey.lastFailedSignIn, .datetime)
                .field(FieldKey.lastSignInAt, .datetime)
                .field(FieldKey.accountLocked, .bool, .required)
                .field(FieldKey.lockoutUntil, .datetime)
                .field(FieldKey.requirePasswordChange, .bool, .required)
                .field(FieldKey.totpMFAEnabled, .bool, .required)
                .field(FieldKey.totpMFASecret, .string)
                .field(FieldKey.emailMFAEnabled, .bool, .required)
                .field(FieldKey.passwordHistory, .array(of: .string))
                .field(FieldKey.tokenVersion, .int, .required)
                .field(FieldKey.createdAt, .datetime)
                .field(FieldKey.updatedAt, .datetime)
                .create()
        }
        
        func revert(on database: Database) async throws {
            try await database.schema(User.schema).delete()
        }
    }
}
