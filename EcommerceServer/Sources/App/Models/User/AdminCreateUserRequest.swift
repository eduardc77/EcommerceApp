import Hummingbird

/// Create user request object for admin user creation
struct AdminCreateUserRequest: Decodable, Sendable {
    let username: String
    let displayName: String
    let email: String
    let password: String
    let profilePicture: String?
    let role: Role

    enum CodingKeys: String, CodingKey {
        case username
        case displayName = "display_name"
        case email
        case password
        case profilePicture = "profile_picture"
        case role
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Reuse validation logic from SignUpRequest
        let baseRequest = try SignUpRequest(from: decoder)
        self.username = baseRequest.username
        self.displayName = baseRequest.displayName
        self.email = baseRequest.email
        self.password = baseRequest.password
        self.profilePicture = baseRequest.profilePicture
        
        // Add role validation
        self.role = try container.decode(Role.self, forKey: .role)
    }

    init(
        username: String,
        displayName: String,
        email: String,
        password: String,
        profilePicture: String? = "https://api.dicebear.com/7.x/avataaars/png",
        role: Role
    ) throws {
        do {
            // Reuse validation from SignUpRequest
            let baseRequest = try SignUpRequest(
                username: username,
                displayName: displayName,
                email: email,
                password: password,
                profilePicture: profilePicture
            )
            self.username = baseRequest.username
            self.displayName = baseRequest.displayName
            self.email = baseRequest.email
            self.password = baseRequest.password
            self.profilePicture = baseRequest.profilePicture
            self.role = role
        } catch let error as HTTPError {
            throw error
        } catch {
            throw HTTPError(.badRequest, message: "Invalid user data format")
        }
    }
}
