import Foundation
import Hummingbird
import HummingbirdFluent
import FluentKit
import JWTKit

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
    
    /// Add public routes
    func addPublicRoutes(to group: RouterGroup<Context>) {
        // No public routes needed
    }
    
    /// Add protected routes that require authentication
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.put("update-profile", use: updateProfile)
            .get(":id/public", use: getUserPublic)
            .get(":id", use: getUser)
            .put(":id", use: adminUpdate)
            .delete(":id", use: deleteUser)
            .put(":id/role", use: updateRole)
    }
    
    /// Create a new user (admin endpoint)
    @Sendable func create(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        let createUser = try await request.decode(
            as: AdminCreateUserRequest.self,
            context: context
        )
        
        // Check role permissions if a role is specified
        if let currentUser = context.identity {
            // If authenticated user is creating another user, check permissions
            switch currentUser.role {
            case .admin:
                // Admin can create users with any role
                break
            case .staff:
                // Staff can only create customers or sellers
                guard createUser.role == .customer || createUser.role == .seller else {
                    throw HTTPError(.forbidden, message: "Staff can only create customer or seller accounts")
                }
            case .seller:
                // Sellers can only create customer accounts
                guard createUser.role == .customer else {
                    throw HTTPError(.forbidden, message: "Sellers can only create customer accounts")
                }
            case .customer:
                // Customers cannot create users
                throw HTTPError(.forbidden, message: "You do not have permission to create users")
            }
        } else {
            // Unauthenticated users cannot create users
            throw HTTPError(.forbidden, message: "Authentication required")
        }

        context.logger.info("Creating new user: \(createUser.username)")
        
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
        
        // Create user with specified role
        let user = try await User(from: createUser)
        try await user.save(on: db)
        
        context.logger.info("Successfully created user: \(user.username)")
        
        return .init(
            status: .created,
            response: UserResponse(from: user)
        )
    }
    
    /// Update own profile (for any authenticated user)
    @Sendable func updateProfile(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        guard let user = context.identity else { throw HTTPError(.unauthorized) }
        let updateUser = try await request.decode(as: UpdateUserRequest.self, context: context)
        let db = self.fluent.db()
        
        // Prevent role updates through this endpoint
        if updateUser.role != nil {
            throw HTTPError(.forbidden, message: "Cannot update role through this endpoint")
        }
        
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
        
        // Update profile picture if provided
        if let profilePicture = updateUser.profilePicture {
            user.profilePicture = profilePicture
        }
        
        try await user.save(on: db)
        return .init(status: .ok, response: UserResponse(from: user))
    }

    /// Admin-only endpoint to update any user
    @Sendable func adminUpdate(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<UserResponse> {
        guard let currentUser = context.identity else {
            throw HTTPError(.unauthorized)
        }
        
        // Only admins can use this endpoint
        guard currentUser.role == .admin else {
            throw HTTPError(.forbidden, message: "Only administrators can update other users")
        }

        // Get user ID from path parameters
        guard let userIDString = request.uri.path.split(separator: "/").last,
              let userID = UUID(uuidString: String(userIDString)) else {
            throw HTTPError(.badRequest, message: "Invalid user ID format")
        }

        // Find user to update
        guard let user = try await User.find(userID, on: fluent.db()) else {
            throw HTTPError(.notFound, message: "User not found")
        }

        let updateUser = try await request.decode(as: UpdateUserRequest.self, context: context)
        
        // Apply updates
        if let displayName = updateUser.displayName {
            user.displayName = displayName
        }
        
        if let email = updateUser.email {
            // Check email availability
            let existingEmail = try await User.query(on: fluent.db())
                .filter(\.$email == email)
                .filter(\.$id != userID)  // Exclude current user
                .first()
                
            guard existingEmail == nil else {
                throw HTTPError(.conflict, message: "Email already exists")
            }
            
            user.email = email
            user.emailVerified = false
            user.tokenVersion += 1
        }
        
        if let profilePicture = updateUser.profilePicture {
            user.profilePicture = profilePicture
        }
        
        try await user.save(on: fluent.db())
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
    let profilePicture: String?
    let role: Role?
}

