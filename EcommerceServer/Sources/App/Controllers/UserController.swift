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
    
    init(jwtKeyCollection: JWTKeyCollection, kid: JWKIdentifier, fluent: Fluent, tokenStore: TokenStoreProtocol) {
        self.jwtKeyCollection = jwtKeyCollection
        self.kid = kid
        self.fluent = fluent
        self.tokenStore = tokenStore
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
            try await user.save(on: db)
            context.logger.info("Successfully created user: \(user.username)")
            
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
}

struct UpdateUserRequest: Codable, Sendable {
    let displayName: String?
    let email: String?
    let password: String?
    let avatar: String?
    let role: Role?
} 
