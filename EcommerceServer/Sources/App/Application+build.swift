import AsyncHTTPClient
import Foundation
import FluentKit
import FluentSQLiteDriver
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import JWTKit
import ServiceLifecycle
import Crypto
import NIOCore
import NIOHTTP1
import NIOPosix

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
}

typealias AppRequestContext = BasicAuthRequestContext<User>

struct DatabaseService: Service {
    let fluent: Fluent

    func run() async throws {
        // Ignore cancellation error
        try? await gracefulShutdown()
        try await self.fluent.shutdown()
    }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    // Initialize logger
    let logger = {
        var logger = Logger(label: "auth-jwt")
        logger.logLevel = .debug
        return logger
    }()

    let fluent = Fluent(logger: logger)
    // add sqlite database
    if args.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        fluent.databases.use(.sqlite(.file("db.sqlite")), as: .sqlite)
    }

    // add migrations
    await fluent.migrations.add(CreateUser())
    
    // migrate
    if args.migrate || args.inMemoryDatabase {
        try await fluent.migrate()
    }

    let jwtAuthenticator = JWTAuthenticator(fluent: fluent)
    let jwtLocalSignerKid = JWKIdentifier("hb_local")

    // Validate and get JWT secret
    let jwtSecret = AppConfig.jwtSecret
    guard !jwtSecret.isEmpty else {
        throw HTTPError(.internalServerError, message: "JWT secret cannot be empty")
    }
    
    guard let secretData = jwtSecret.data(using: .utf8) else {
        throw HTTPError(.internalServerError, message: "JWT secret must be valid UTF-8")
    }

    await jwtAuthenticator.useSigner(
        hmac: HMACKey(key: SymmetricKey(data: secretData)),
        digestAlgorithm: .sha256,
        kid: jwtLocalSignerKid
    )

    // Create regular JWT authenticator for user routes
    let userJWTAuthenticator = JWTAuthenticator(fluent: fluent)
    await userJWTAuthenticator.useSigner(
        hmac: HMACKey(key: SymmetricKey(data: secretData)),
        digestAlgorithm: .sha256,
        kid: jwtLocalSignerKid
    )

    let router = Router(context: AppRequestContext.self)
    router.add(middleware: LogRequestsMiddleware(.debug))
    
    router.get("/") { _, _ in
        "Hello"
    }
    
    router.get("/health") { _, _ in
        EditedResponse(
            status: .ok,
            response: ["status": "healthy", "timestamp": Date().ISO8601Format()]
        )
    }
    
    router.get("/slow") { _, _ in
        try await Task.sleep(for: .seconds(3))
        return EditedResponse(
            status: .ok,
            response: ["message": "Slow request completed", "timestamp": Date().ISO8601Format()]
        )
    }
    
    // Create a base API group with CORS middleware
    let api = router.group("api")
        .add(middleware: CORSMiddleware(
            allowOrigin: .custom(AppConfig.allowedOrigins.joined(separator: ", ")),
            allowHeaders: [.accept, .authorization, .contentType, .origin],
            allowMethods: [.get, .post, .put, .delete, .options],
            allowCredentials: true,
            maxAge: .seconds(3600)
        ))
        .add(middleware: RateLimiterMiddleware<AppRequestContext>(
            requestsPerMinute: AppConfig.requestsPerMinute,
            whitelist: AppConfig.rateLimitWhitelist
        ))
    
    let userController = UserController(
        jwtKeyCollection: userJWTAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent
    )
    
    // Add user routes - split into public and protected
    let usersGroup = api.group("users")
    
    // Add public routes (registration, availability)
    userController.addPublicRoutes(to: usersGroup)
    
    // Add protected routes (me, update)
    userController.addProtectedRoutes(to: usersGroup.add(middleware: userJWTAuthenticator))
    
    // Create a protected auth group that will be used for all protected routes
    let protectedAuthGroup = api.group("auth")
        .add(middleware: jwtAuthenticator)
    
    AuthController(
        jwtKeyCollection: jwtAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent
    ).addProtectedRoutes(to: protectedAuthGroup)
    
    // Add public auth routes (login, register) to a separate group
    AuthController(
        jwtKeyCollection: jwtAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent
    ).addPublicRoutes(to: api.group("auth"))

    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "auth-jwt"
        ),
        logger: logger
    )
    
    app.addServices(DatabaseService(fluent: fluent))
    
    return app
}
