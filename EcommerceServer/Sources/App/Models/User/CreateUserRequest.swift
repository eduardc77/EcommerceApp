import Foundation
import Hummingbird

/// Response for password validation feedback
struct PasswordValidationResponse: Encodable {
    let isValid: Bool
    let errors: [String]
    let strength: String
    let strengthColor: String
    let suggestions: [String]
}

/// Create user request object decoded from HTTP body
struct CreateUserRequest: Decodable, Sendable {
    let username: String
    let displayName: String
    let email: String
    let password: String
    let avatar: String?
    let role: Role?

    enum CodingKeys: String, CodingKey {
        case username
        case displayName
        case email
        case password
        case avatar
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode and validate all fields
        do {
            self.username = try container.decode(String.self, forKey: .username)
            guard !username.isEmpty else {
                throw HTTPError(.badRequest, message: "Missing required field: username")
            }
            guard username.count >= 3 else {
                throw HTTPError(.badRequest, message: "Invalid username: Must be at least 3 characters long")
            }
        } catch DecodingError.keyNotFound {
            throw HTTPError(.badRequest, message: "Missing required field: username")
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError(.badRequest, message: "Invalid username format")
        }
        
        do {
            self.displayName = try container.decode(String.self, forKey: .displayName)
            guard !displayName.isEmpty else {
                throw HTTPError(.badRequest, message: "Missing required field: displayName")
            }
        } catch DecodingError.keyNotFound {
            throw HTTPError(.badRequest, message: "Missing required field: displayName")
        } catch {
            throw HTTPError(.badRequest, message: "Invalid displayName format")
        }
        
        do {
            self.email = try container.decode(String.self, forKey: .email)
            guard !email.isEmpty else {
                throw HTTPError(.badRequest, message: "Missing required field: email")
            }
            // Basic email format validation
            guard email.contains("@") && email.contains(".") else {
                throw HTTPError(.badRequest, message: "Invalid email format: expected valid email address")
            }
        } catch DecodingError.keyNotFound {
            throw HTTPError(.badRequest, message: "Missing required field: email")
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError(.badRequest, message: "Invalid email format")
        }
        
        do {
            self.password = try container.decode(String.self, forKey: .password)
            guard !password.isEmpty else {
                throw HTTPError(.badRequest, message: "Missing required field: password")
            }
        } catch DecodingError.keyNotFound {
            throw HTTPError(.badRequest, message: "Missing required field: password")
        } catch {
            throw HTTPError(.badRequest, message: "Invalid password format")
        }
        
        // Make avatar optional with a default value
        self.avatar = try container.decodeIfPresent(String.self, forKey: .avatar) ?? "https://api.dicebear.com/7.x/avataaars/png"
        self.role = try container.decodeIfPresent(Role.self, forKey: .role)
        
        // Validate password using the new validator with user info
        let validator = PasswordValidator()
        let userInfo = [
            "username": username,
            "displayName": displayName,
            "email": email
        ]
        let result = validator.validate(password, userInfo: userInfo)
        
        if !result.isValid {
            let message = "Invalid password: " + (result.firstError ?? "Password validation failed")
            throw HTTPError(.init(code: 422), message: message)
        }
    }

    init(
        username: String,
        displayName: String,
        email: String,
        password: String,
        avatar: String? = "https://api.dicebear.com/7.x/avataaars/png",
        role: Role? = nil
    ) throws {
        // Validate username
        guard !username.isEmpty else {
            throw HTTPError(.badRequest, message: "Missing required field: username")
        }
        guard username.count >= 3 else {
            throw HTTPError(.badRequest, message: "Invalid username: Must be at least 3 characters long")
        }
        self.username = username
        
        // Validate displayName
        guard !displayName.isEmpty else {
            throw HTTPError(.badRequest, message: "Missing required field: displayName")
        }
        self.displayName = displayName
        
        // Validate email
        guard !email.isEmpty else {
            throw HTTPError(.badRequest, message: "Missing required field: email")
        }
        guard email.contains("@") && email.contains(".") else {
            throw HTTPError(.badRequest, message: "Invalid email format: expected valid email address")
        }
        self.email = email
        
        // Validate password
        guard !password.isEmpty else {
            throw HTTPError(.badRequest, message: "Missing required field: password")
        }
        self.password = password
        
        self.avatar = avatar
        self.role = role
        
        // Validate password using the new validator with user info
        let validator = PasswordValidator()
        let userInfo = [
            "username": username,
            "displayName": displayName,
            "email": email
        ]
        let result = validator.validate(password, userInfo: userInfo)
        
        if !result.isValid {
            let message = "Invalid password: " + (result.firstError ?? "Password validation failed")
            throw HTTPError(.init(code: 422), message: message)
        }
    }

    private static func validatePassword(_ password: String) throws {
        let config = JWTConfiguration.load()
        print("Validating password: length=\(password.count), minRequired=\(config.minimumPasswordLength)")  // Debug log
        
        // Check length
        guard password.count >= config.minimumPasswordLength else {
            throw HTTPError(.badRequest, message: "Password must be at least \(config.minimumPasswordLength) characters long")
        }
        guard password.count <= config.maximumPasswordLength else {
            throw HTTPError(.badRequest, message: "Password must not exceed \(config.maximumPasswordLength) characters")
        }

        // Check complexity
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSpecialChar = password.contains(where: { "!@#$%^&*()_+-=[]{}|;:,.<>?".contains($0) })
        
        var requirements: [String] = []
        if !hasUppercase { requirements.append("an uppercase letter") }
        if !hasLowercase { requirements.append("a lowercase letter") }
        if !hasNumber { requirements.append("a number") }
        if !hasSpecialChar { requirements.append("a special character") }
        
        guard requirements.isEmpty else {
            let missing = requirements.joined(separator: ", ")
            throw HTTPError(.badRequest, message: "Password must contain \(missing)")
        }
        
        // Check for common patterns
        let lowercasePassword = password.lowercased()
        let commonPatterns = [
            "password", "123456", "qwerty", "admin", "letmein", 
            "welcome", "abc123", "monkey", "dragon", "football",
            "baseball", "master", "login", "admin123", "root",
            "shadow", "qwerty123", "123qwe", "1234", "12345"
        ]
        
        for pattern in commonPatterns {
            guard !lowercasePassword.contains(pattern) else {
                throw HTTPError(.badRequest, message: "Password contains common patterns that are not allowed")
            }
        }
        
        // Check for sequential characters
        let sequences = ["abcdefghijklmnopqrstuvwxyz", "12345678901234567890"]
        for sequence in sequences {
            let sequenceLength = 4
            guard !sequence.windows(ofCount: sequenceLength).contains(where: { 
                lowercasePassword.contains($0.lowercased())
            }) else {
                throw HTTPError(.badRequest, message: "Password contains sequential characters")
            }
        }
        
        // Check for repeated characters
        let maxRepeatedChars = 3
        for i in 0...(password.count - maxRepeatedChars) {
            let start = password.index(password.startIndex, offsetBy: i)
            let end = password.index(start, offsetBy: maxRepeatedChars)
            let substring = password[start..<end]
            let allSame = substring.allSatisfy { $0 == substring.first }
            guard !allSame else {
                throw HTTPError(.badRequest, message: "Password contains too many repeated characters")
            }
        }
    }
} 
