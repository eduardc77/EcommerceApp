// Core imports
import Foundation
import Logging

// Hummingbird imports
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent

// Database imports
import FluentKit
import FluentSQLiteDriver

// Networking imports
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import NIOPosix

// Security imports
import Crypto
import JWTKit

// Service imports
import ServiceLifecycle

protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var inMemoryDatabase: Bool { get }
    var migrate: Bool { get }
    var isTestEnvironment: Bool { get }
}

extension AppArguments {
    var isTestEnvironment: Bool {
        ProcessInfo.processInfo.environment["APP_ENV"] == "testing"
    }
    
    var environment: String {
        ProcessInfo.processInfo.environment["APP_ENV"] ?? "development"
    }
}

typealias AppRequestContext = BasicAuthRequestContext<User>

struct DatabaseService: Service {
    let fluent: Fluent
    let httpClient: HTTPClient

    func run() async throws {
        // Ignore cancellation error
        try? await gracefulShutdown()
        try await self.fluent.shutdown()
        try await self.httpClient.shutdown()
    }
}

func buildApplication(_ args: AppArguments) async throws -> some ApplicationProtocol {
    // Load environment variables from .env file
    loadEnvironment()
    
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
    await fluent.migrations.add(AddEmailVerificationEnabled())
    await fluent.migrations.add(EmailVerificationCode.Migration())
    
    // migrate
    if args.migrate || args.inMemoryDatabase {
        try await fluent.migrate()
    }

    // Initialize token store
    let tokenStore = TokenStore(logger: logger)

    let jwtAuthenticator = JWTAuthenticator(fluent: fluent, tokenStore: tokenStore)
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
    let userJWTAuthenticator = JWTAuthenticator(fluent: fluent, tokenStore: tokenStore)
    await userJWTAuthenticator.useSigner(
        hmac: HMACKey(key: SymmetricKey(data: secretData)),
        digestAlgorithm: .sha256,
        kid: jwtLocalSignerKid
    )

    // Create HTTP client
    let httpClient = HTTPClient(eventLoopGroupProvider: .singleton)

    // Initialize email service based on environment
    let emailService: EmailService = {
        if Environment.current.isTesting {
            return MockEmailService(logger: logger)
        } else {
            return SendGridEmailService(
                httpClient: httpClient,
                apiKey: AppConfig.sendGridAPIKey,
                fromEmail: AppConfig.sendGridFromEmail,
                fromName: AppConfig.sendGridFromName,
                logger: logger
            )
        }
    }()

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
            allowHeaders: [.accept, .authorization, .contentType, .origin, .init(AppConfig.csrfHeaderName)!],
            allowMethods: [.get, .post, .put, .delete, .options],
            allowCredentials: true,
            maxAge: .seconds(3600)
        ))
        // Add CSRF protection middleware if enabled
        .add(middleware: AppConfig.csrfProtectionEnabled ? CSRFProtectionMiddleware(
            cookieName: AppConfig.csrfCookieName,
            headerName: AppConfig.csrfHeaderName,
            secureCookies: AppConfig.csrfSecureCookies,
            sameSite: AppConfig.csrfSameSite,
            exemptPaths: AppConfig.csrfExemptPaths
        ) : NoopMiddleware())
        .add(middleware: RateLimiterMiddleware<AppRequestContext>(
            requestsPerMinute: AppConfig.requestsPerMinute,
            whitelist: AppConfig.rateLimitWhitelist,
            trustedProxies: AppConfig.trustedProxies,
            useXForwardedFor: AppConfig.environment.isProduction || AppConfig.environment.isStaging,
            useXRealIP: AppConfig.environment.isProduction || AppConfig.environment.isStaging
        ))
    
    let userController = UserController(
        jwtKeyCollection: userJWTAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent,
        tokenStore: tokenStore,
        emailService: emailService
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
    
    let authController = AuthController(
        jwtKeyCollection: jwtAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent,
        tokenStore: tokenStore,
        emailService: emailService
    )
    
    // Add TOTP routes to protected auth group
    let totpController = TOTPController(fluent: fluent)
    totpController.addProtectedRoutes(to: protectedAuthGroup.group("totp"))
    
    // Add email verification routes to protected auth group
    let emailVerificationController = EmailVerificationController(fluent: fluent, emailService: emailService)
    emailVerificationController.addProtectedRoutes(to: protectedAuthGroup.group("email"))
    emailVerificationController.addPublicRoutes(to: api.group("auth/email"))
    
    // Add protected auth routes
    authController.addProtectedRoutes(to: protectedAuthGroup)
    
    // Add public auth routes (login, register) to a separate group
    authController.addPublicRoutes(to: api.group("auth"))

    var app = Application(
        router: router,
        configuration: .init(
            address: .hostname(args.hostname, port: args.port),
            serverName: "auth-jwt"
        ),
        logger: logger
    )
    
    app.addServices(DatabaseService(fluent: fluent, httpClient: httpClient))
    
    return app
}

/// Load environment variables from .env file
private func loadEnvironment() {
    guard let contents = try? String(contentsOfFile: ".env", encoding: .utf8) else {
        return
    }
    
    let lines = contents.components(separatedBy: .newlines)
    for line in lines {
        let parts = line.components(separatedBy: "=")
        guard parts.count == 2 else { continue }
        
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        setenv(key, value, 1)
    }
}
