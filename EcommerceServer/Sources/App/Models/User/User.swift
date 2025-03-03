import HummingbirdBcrypt
import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBasicAuth
import HummingbirdFluent

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
    
    @Field(key: "avatar")
    var avatar: String?
    
    @Enum(key: "role")
    var role: Role
    
    @OptionalField(key: "password_hash")
    var passwordHash: String?
    
    @OptionalField(key: "password_updated_at")
    var passwordUpdatedAt: Date?
    
    @Field(key: "email_verified")
    var emailVerified: Bool
    
    @Field(key: "failed_login_attempts")
    var failedLoginAttempts: Int
    
    @OptionalField(key: "last_failed_login")
    var lastFailedLogin: Date?
    
    @OptionalField(key: "last_login_at")
    var lastLoginAt: Date?
    
    @Field(key: "account_locked")
    var accountLocked: Bool
    
    @OptionalField(key: "lockout_until")
    var lockoutUntil: Date?
    
    @Field(key: "require_password_change")
    var requirePasswordChange: Bool
    
    @Field(key: "two_factor_enabled")
    var twoFactorEnabled: Bool
    
    @OptionalField(key: "two_factor_secret")
    var twoFactorSecret: String?
    
    @OptionalField(key: "password_history")
    var passwordHistory: [String]?
    
    @Field(key: "token_version")
    var tokenVersion: Int
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    /// Maximum number of password history entries to keep
    private static let maxPasswordHistoryCount = 5
    
    init() {}
    
    init(
        id: UUID? = nil,
        username: String,
        displayName: String,
        email: String,
        avatar: String? = nil,
        role: Role = .customer,
        passwordHash: String?,
        emailVerified: Bool = false,
        failedLoginAttempts: Int = 0,
        lastFailedLogin: Date? = nil,
        lastLoginAt: Date? = nil,
        accountLocked: Bool = false,
        lockoutUntil: Date? = nil,
        requirePasswordChange: Bool = false,
        twoFactorEnabled: Bool = false,
        twoFactorSecret: String? = nil,
        passwordUpdatedAt: Date? = nil,
        passwordHistory: [String]? = nil,
        tokenVersion: Int = 0
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.email = email
        self.avatar = avatar
        self.role = role
        self.passwordHash = passwordHash
        self.emailVerified = emailVerified
        self.failedLoginAttempts = failedLoginAttempts
        self.lastFailedLogin = lastFailedLogin
        self.lastLoginAt = lastLoginAt
        self.accountLocked = accountLocked
        self.lockoutUntil = lockoutUntil
        self.requirePasswordChange = requirePasswordChange
        self.twoFactorEnabled = twoFactorEnabled
        self.twoFactorSecret = twoFactorSecret
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
        self.avatar = nil
        self.role = .customer
        self.passwordHash = nil
        self.emailVerified = true
        self.failedLoginAttempts = 0
        self.lastFailedLogin = nil
        self.lastLoginAt = nil
        self.accountLocked = false
        self.lockoutUntil = nil
        self.requirePasswordChange = false
        self.twoFactorEnabled = false
        self.twoFactorSecret = nil
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
    
    init(from userRequest: CreateUserRequest) async throws {
        // Validate password first with user info for better validation
        try Self.validatePassword(userRequest.password, userInfo: [
            "username": userRequest.username,
            "email": userRequest.email
        ])
        
        self.id = nil
        self.username = userRequest.username
        self.displayName = userRequest.displayName
        self.email = userRequest.email
        self.avatar = userRequest.avatar ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = userRequest.role ?? .customer
        self.emailVerified = false
        self.failedLoginAttempts = 0
        self.lastFailedLogin = nil
        self.lastLoginAt = nil
        self.accountLocked = false
        self.lockoutUntil = nil
        self.requirePasswordChange = false
        self.twoFactorEnabled = false
        self.twoFactorSecret = nil
        self.passwordHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(userRequest.password, cost: 12)
        }
        self.passwordUpdatedAt = Date()
        self.passwordHistory = nil
        self.tokenVersion = 0
    }
    
    /// Create an SSO email address for a user
    static func createSSOEmail(for username: String) -> String {
        return "\(username)@\(ssoEmailDomain)"
    }
    
    func incrementFailedLoginAttempts() {
        self.failedLoginAttempts += 1
        self.lastFailedLogin = Date()
        
        // Auto-lock account after too many failed attempts
        if self.failedLoginAttempts >= 5 {
            self.accountLocked = true
            self.lockoutUntil = Date().addingTimeInterval(15 * 60) // 15 minutes
        }
    }
    
    func resetFailedLoginAttempts() {
        self.failedLoginAttempts = 0
        self.lastFailedLogin = nil
        self.accountLocked = false
        self.lockoutUntil = nil
    }
    
    func updateLastLogin() {
        self.lastLoginAt = Date()
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
        // Hash the new password
        let newHash = try await NIOThreadPool.singleton.runIfActive {
            Bcrypt.hash(newPassword, cost: 12)
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
    }
}

extension User {
    enum FieldKey {
        static let username: FluentKit.FieldKey = "username"
        static let displayName: FluentKit.FieldKey = "display_name"
        static let email: FluentKit.FieldKey = "email"
        static let avatar: FluentKit.FieldKey = "avatar"
        static let role: FluentKit.FieldKey = "role"
        static let failedLoginAttempts: FluentKit.FieldKey = "failed_login_attempts"
        static let lastFailedLogin: FluentKit.FieldKey = "last_failed_login"
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
                .field(FieldKey.avatar, .string)
                .field(FieldKey.role, .string, .required)
                .field(FieldKey.failedLoginAttempts, .int, .required)
                .field(FieldKey.lastFailedLogin, .datetime)
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
