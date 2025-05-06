/// Available MFA methods
public enum MFAMethod: String, Codable, Sendable {
    case totp = "totp"
    case email = "email"
    case recoveryCode = "recovery_code"
}
