/// Request model for selecting which MFA method to use during sign-in
struct MFASelectionRequest: Codable {
    /// The state token from the initial sign-in attempt
    let stateToken: String
    
    /// The selected MFA method (totp or email)
    let method: MFAMethod
} 
