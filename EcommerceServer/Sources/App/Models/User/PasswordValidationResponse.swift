/// Response for password validation feedback
struct PasswordValidationResponse: Encodable {
    let isValid: Bool
    let errors: [String]
    let strength: String
    let strengthColor: String
    let suggestions: [String]

    enum CodingKeys: String, CodingKey {
        case isValid = "is_valid"
        case errors
        case strength
        case strengthColor = "strength_color"
        case suggestions
    }
}
