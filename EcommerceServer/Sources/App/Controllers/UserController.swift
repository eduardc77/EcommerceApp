import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import JWTKit
import NIO

struct UserController {
    typealias Context = AppRequestContext
    let jwtKeyCollection: JWTKeyCollection
    let kid: JWKIdentifier
    let fluent: Fluent
    private let tokenStore: TokenStoreProtocol
    private let emailService: EmailService
    
    init(jwtKeyCollection: JWTKeyCollection, kid: JWKIdentifier, fluent: Fluent, tokenStore: TokenStoreProtocol, emailService: EmailService) {
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.fluent = fluent
        self.tokenStore = tokenStore
        self.emailService = emailService
    }
    
    /// Add public routes (registration, availability)
    func addPublicRoutes(to group: RouterGroup<Context>) {
        // Registration endpoint
        group.post("register", use: self.create)
        
        // Group availability checks under /availability
        let availabilityGroup = group.group("availability")
        availabilityGroup.get(use: checkAvailability)
    }
    
    /// Add protected routes that require authentication
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.put("me", use: update)
        group.get(":id/public", use: getUserPublic)  // Public details endpoint
        group.get(":id", use: getUser)  // Full details endpoint
        group.delete(":id", use: deleteUser)
        group.put(":id/role", use: updateRole)  // New endpoint for role management
    }
    
    /// Add all routes (deprecated)
    @available(*, deprecated, message: "Use addPublicRoutes and addProtectedRoutes instead")
    func addRoutes(to group: RouterGroup<Context>) {
        addPublicRoutes(to: group)
        addProtectedRoutes(to: group)
    }
    
    /// Create new user
    @Sendable func create(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        do {
            let createUser = try await request.decode(
                as: CreateUserRequest.self,
                context: context
            )
            
            // Check role permissions if a role is specified
            if let requestedRole = createUser.role {
                if let currentUser = context.identity {
                    // If authenticated user is creating another user, check permissions
                    switch currentUser.role {
                    case .admin:
                        // Admin can create users with any role
                        break
                    case .staff:
                        // Staff can only create customers or sellers
                        guard requestedRole == .customer || requestedRole == .seller else {
                            throw HTTPError(.forbidden, message: "Staff can only create customer or seller accounts")
                        }
                    case .seller:
                        // Sellers can only create customer accounts
                        guard requestedRole == .customer else {
                            throw HTTPError(.forbidden, message: "Sellers can only create customer accounts")
                        }
                    case .customer:
                        // Customers cannot specify roles
                        throw HTTPError(.forbidden, message: "You cannot specify a role when creating an account")
                    }
                } else {
                    // Unauthenticated users cannot specify roles
                    throw HTTPError(.forbidden, message: "You cannot specify a role when creating an account")
                }
            }

            context.logger.info("Decoded create user request: \(createUser.username)")
            
            let db = self.fluent.db()
            
            // Check if username exists
            let existingUsername = try await User.query(on: db)
                .filter(\.$username == createUser.username)
                .first()
            guard existingUsername == nil else {
                context.logger.notice("Username already exists: \(createUser.username)")
                throw HTTPError(.conflict, message: "Username already exists")
            }
            
            // Check if email exists
            let existingEmail = try await User.query(on: db)
                .filter(\.$email == createUser.email)
                .first()
            guard existingEmail == nil else {
                context.logger.notice("Email already exists: \(createUser.email)")
                throw HTTPError(.conflict, message: "Email already exists")
            }
            
            context.logger.info("Creating new user: \(createUser.username)")
            let user = try await User(from: createUser)
            
            // Save both user and verification code in a transaction
            try await db.transaction { database in
                // Save user first
                try await user.save(on: database)
                
                // Generate and store verification code
                let code = EmailVerificationCode.generateCode()
                let verificationCode = EmailVerificationCode(
                    userID: try user.requireID(),
                    code: code,
                    type: "email_verify",
                    expiresAt: Date().addingTimeInterval(300) // 5 minutes
                )
                
                try await verificationCode.save(on: database)
                
                // Send verification email
                try await emailService.sendVerificationEmail(to: user.email, code: code)
            }
            
            context.logger.info("Successfully created user and sent verification email: \(user.username)")
            
            return .init(status: .created, response: UserResponse(from: user))
        } catch {
            context.logger.error("Failed to create user: \(error)")
            throw error
        }
    }
    
    /// Check availability of username or email
    /// Returns 200 OK with availability status
    /// Query parameters:
    /// - username: Username to check
    /// - email: Email to check
    /// Example:
    /// GET /user/availability?username=john123
    /// GET /user/availability?email=john@example.com
    @Sendable func checkAvailability(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<AvailabilityResponse> {
        let db = self.fluent.db()
        
        // Get query parameters
        if let username = request.uri.queryParameters.get("username", as: String.self) {
            let existingUser = try await User.query(on: db)
                .filter(\.$username == username)
                .first()
            
            return .init(
                status: .ok,
                response: AvailabilityResponse(
                    available: existingUser == nil,
                    identifier: username,
                    type: "username"
                )
            )
        } else if let email = request.uri.queryParameters.get("email", as: String.self) {
            let existingUser = try await User.query(on: db)
                .filter(\.$email == email)
                .first()
            
            return .init(
                status: .ok,
                response: AvailabilityResponse(
                    available: existingUser == nil,
                    identifier: email,
                    type: "email"
                )
            )
        }
        
        throw HTTPError(.badRequest, message: "Either 'username' or 'email' query parameter is required")
    }
    
    /// Update existing user
    @Sendable func update(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        guard let user = context.identity else { throw HTTPError(.unauthorized) }
        let updateUser = try await request.decode(as: UpdateUserRequest.self, context: context)
        let db = self.fluent.db()
        
        // Update display name if provided
        if let newDisplayName = updateUser.displayName {
            user.displayName = newDisplayName
        }
        
        // If updating email, check if it's available and update token version
        if let newEmail = updateUser.email, newEmail != user.email {
            let existingEmail = try await User.query(on: db)
                .filter(\.$email == newEmail)
                .first()
            guard existingEmail == nil else {
                throw HTTPError(.conflict, message: "Email already exists")
            }
            
            // Store current token for invalidation
            let currentToken = request.headers.bearer?.token
            
            // Update email and related fields
            user.email = newEmail
            user.emailVerified = false
            user.tokenVersion += 1  // Increment token version to invalidate all existing tokens
            
            // Save the changes
            try await user.save(on: db)
            
            // Invalidate token immediately
            if let token = currentToken {
                // Get token expiration from JWT payload
                let payload = try await self.jwtKeyCollection.verify(token, as: JWTPayloadData.self)
                
                // Blacklist the token
                await tokenStore.blacklist(token, expiresAt: payload.expiration.value, reason: .tokenVersionChange)
            }
            
            // Create and return response
            return .init(status: .ok, response: UserResponse(from: user))
        }
        
        // Update avatar if provided
        if let avatar = updateUser.avatar {
            user.avatar = avatar
        }
        
        try await user.save(on: db)
        return .init(status: .ok, response: UserResponse(from: user))
    }
    
    /// Get a specific user's public details by ID
    @Sendable func getUserPublic(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<PublicUserResponse> {
        guard let _ = context.identity else {
            throw HTTPError(.unauthorized)
        }

        // Get user ID from path parameters
        guard let userIDString = request.uri.path.split(separator: "/").dropLast().last,
              let userID = UUID(uuidString: String(userIDString)) else {
            throw HTTPError(.badRequest, message: "Invalid user ID format")
        }

        // Find user
        guard let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.notFound, message: "User not found")
        }

        return EditedResponse(status: .ok, response: PublicUserResponse(from: user))
    }

    /// Get a specific user by ID
    /// Returns full details for own profile or admin
    @Sendable func getUser(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        guard let currentUser = context.identity else {
            throw HTTPError(.unauthorized)
        }

        // Get user ID from path parameters
        guard let userIDString = request.uri.path.split(separator: "/").last,
              let userID = UUID(uuidString: String(userIDString)) else {
            throw HTTPError(.badRequest, message: "Invalid user ID format")
        }

        // Find user
        guard let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.notFound, message: "User not found")
        }

        // Return full details if admin or own profile
        if currentUser.role == .admin || currentUser.id == userID {
            return EditedResponse(status: .ok, response: UserResponse(from: user))
        }

        // Return forbidden for others
        throw HTTPError(.forbidden, message: "You don't have permission to access this user's details")
    }

    /// Delete a user
    /// Only admins can delete users, or users can delete their own account
    @Sendable func deleteUser(
        _ request: Request,
        context: Context
    ) async throws -> Response {
        guard let currentUser = context.identity else {
            throw HTTPError(.unauthorized)
        }

        // Get user ID from path parameters
        guard let userIDString = request.uri.path.split(separator: "/").last,
              let userID = UUID(uuidString: String(userIDString)) else {
            throw HTTPError(.badRequest, message: "Invalid user ID format")
        }

        // If not admin and trying to delete another user
        if !currentUser.role.isAdmin && currentUser.id != userID {
            throw HTTPError(.forbidden, message: "You don't have permission to delete this user")
        }

        // Find user
        guard let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.notFound, message: "User not found")
        }

        // Store current token for invalidation
        let currentToken = request.headers.bearer?.token

        // Delete user
        try await user.delete(on: fluent.db())

        // If we have a token and it belongs to the deleted user, blacklist it
        if let token = currentToken,
           let payload = try? await self.jwtKeyCollection.verify(token, as: JWTPayloadData.self),
           payload.subject.value == userID.uuidString {
            await tokenStore.blacklist(token, expiresAt: payload.expiration.value, reason: .tokenVersionChange)
        }

        return Response(status: .noContent)
    }

    /// Update a user's role
    /// Only admins can set admin/staff roles
    /// Staff can set customer/seller roles
    @Sendable func updateRole(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        guard let currentUser = context.identity else {
            throw HTTPError(.unauthorized)
        }

        // Get user ID from path parameters
        guard let userIDString = request.uri.path.split(separator: "/").dropLast().last,
              let userID = UUID(uuidString: String(userIDString)) else {
            throw HTTPError(.badRequest, message: "Invalid user ID format")
        }

        // Decode request
        struct UpdateRoleRequest: Codable {
            let role: Role
        }
        let updateRole = try await request.decode(as: UpdateRoleRequest.self, context: context)

        // Find user to update
        guard let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.notFound, message: "User not found")
        }

        // Check permissions based on role hierarchy
        switch currentUser.role {
        case .admin:
            // Admin can set any role
            break
        case .staff:
            // Staff can only set customer or seller roles
            guard updateRole.role == .customer || updateRole.role == .seller else {
                throw HTTPError(.forbidden, message: "Staff can only assign customer or seller roles")
            }
        case .seller, .customer:
            // Other roles cannot change roles
            throw HTTPError(.forbidden, message: "You don't have permission to change user roles")
        }

        // Cannot change admin's role unless you're an admin
        if user.role == .admin && currentUser.role != .admin {
            throw HTTPError(.forbidden, message: "Only admins can modify admin roles")
        }

        // Update role
        user.role = updateRole.role
        try await user.save(on: fluent.db())

        return .init(status: .ok, response: UserResponse(from: user))
    }
}

struct UpdateUserRequest: Codable, Sendable {
    let displayName: String?
    let email: String?
    let password: String?
    let avatar: String?
    let role: Role?
}

