/// Request model for disabling email MFA with password verification
struct DisableEmailMFARequest: Codable {
    /// The user's password for verification
    let password: String
} 
