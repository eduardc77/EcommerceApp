/// Response for password validation feedback
struct PasswordValidationResponse: Encodable {
    let isValid: Bool
    let errors: [String]
    let strength: String
    let strengthColor: String
    let suggestions: [String]
}
