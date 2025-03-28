// Core imports
import Foundation
import Logging

// Hummingbird imports
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent

// Database imports
import FluentSQLiteDriver

// Networking imports
import AsyncHTTPClient

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
    // Initialize logger first
    let logger = {
        var logger = Logger(label: "auth-jwt")
        logger.logLevel = .debug
        return logger
    }()
    
    // Configure global logger
    AppLogger.configure(logLevel: .debug)
    
    // Load environment variables from .env file
    loadEnvironment(logger: logger)
    
    // Debug: Print current environment and configuration
    logger.info("Current Environment: \(Environment.current)")
    logger.info("APP_ENV: \(ProcessInfo.processInfo.environment["APP_ENV"] ?? "not set")")
    logger.info("Loading from file: .env.\(Environment.current)")
    logger.info("SendGrid API Key: \(AppConfig.sendGridAPIKey.isEmpty ? "not set" : "set (length: \(AppConfig.sendGridAPIKey.count))")")
    logger.info("SendGrid From Email: \(AppConfig.sendGridFromEmail)")
    logger.info("SendGrid From Name: \(AppConfig.sendGridFromName)")

    let fluent = Fluent(logger: logger)
    // add sqlite database
    if args.inMemoryDatabase {
        fluent.databases.use(.sqlite(.memory), as: .sqlite)
    } else {
        // Use absolute path to the database file in the server directory
        let fileManager = FileManager.default
        let serverDirectory = fileManager.currentDirectoryPath
        let dbPath = serverDirectory + "/db.sqlite"
        logger.info("Using database at path: \(dbPath)")
        fluent.databases.use(.sqlite(.file(dbPath)), as: .sqlite)
    }

    // add migrations
    await fluent.migrations.add(CreateUser())
    await fluent.migrations.add(EmailVerificationCode.Migration())
    await fluent.migrations.add(CreateSession())
    await fluent.migrations.add(CreateMFARecoveryCodes())
    await fluent.migrations.add(Token.Migration())
    
    // migrate
    let fileManager = FileManager.default
    let serverDirectory = fileManager.currentDirectoryPath
    let dbPath = serverDirectory + "/db.sqlite"
    let shouldMigrate = args.migrate || args.inMemoryDatabase || !fileManager.fileExists(atPath: dbPath)
    if shouldMigrate {
        logger.info("Running database migrations...")
        
        // For SQLite database, we can directly check tables
        if let sqliteDB = fluent.db() as? SQLDatabase {
            // Check if sessions table exists
            do {
                // Run direct query to check if table exists
                let rows = try await sqliteDB.raw("SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'").all()
                let doesSessionsExist = !rows.isEmpty
                
                // If sessions table exists but might have the wrong schema, drop it first
                if args.migrate && doesSessionsExist {
                    logger.warning("Sessions table exists - dropping before recreating with correct schema")
                    try await sqliteDB.raw("DROP TABLE IF EXISTS sessions").run()
                }
            } catch {
                logger.warning("Could not check sessions table: \(error)")
            }
        }
        
        try await fluent.migrate()
        logger.info("Database migrations completed successfully")
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

    // Create JWT configuration
    let jwtConfiguration = JWTConfiguration.load()

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
    // Important: ErrorHandlerMiddleware should be first in the chain to catch all errors
    router.add(middleware: ErrorHandlerMiddleware())
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
    
    // Debug route to verify API versioning
    router.currentAPIGroup().get("debug-version") { _, _ in
        EditedResponse(
            status: .ok,
            response: [
                "currentVersion": APIVersion.current.rawValue,
                "fullPath": "/api/\(APIVersion.current.rawValue)/debug-version",
                "timestamp": Date().ISO8601Format()
            ]
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
    let api = router.currentAPIGroup()
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
    
    // Initialize controllers
    let totpController = TOTPController(
        fluent: fluent
    )
    let emailVerificationController = EmailMFAController(
        fluent: fluent,
        emailService: emailService
    )
    let mfaRecoveryController = MFARecoveryController(
        fluent: fluent,
        emailService: emailService,
        jwtConfig: jwtConfiguration,
        jwtKeyCollection: jwtAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        tokenStore: tokenStore
    )
    
    let authController = AuthController(
        jwtKeyCollection: jwtAuthenticator.jwtKeyCollection,
        kid: jwtLocalSignerKid,
        fluent: fluent,
        tokenStore: tokenStore,
        emailService: emailService,
        totpController: totpController,
        emailVerificationController: emailVerificationController
    )
    
    // Add protected auth routes
    authController.addProtectedRoutes(to: protectedAuthGroup)
    
    // Add public auth routes
    authController.addPublicRoutes(to: api.group("auth"))

    // Add .well-known endpoints for discovery
    let wellKnownGroup = router.group(".well-known")
    wellKnownGroup.get("jwks.json", use: authController.getJWKS)

    // Sign up TOTP and Email verification routes independently
    totpController.addProtectedRoutes(to: api.group("mfa/totp").add(middleware: jwtAuthenticator))
    emailVerificationController.addProtectedRoutes(to: api.group("mfa/email").add(middleware: jwtAuthenticator))
    mfaRecoveryController.addProtectedRoutes(to: api.group("mfa/recovery").add(middleware: jwtAuthenticator))
    mfaRecoveryController.addPublicRoutes(to: api.group("mfa/recovery"))

    // Add file upload routes
    let fileController = FileController(fluent: fluent)
    fileController.addProtectedRoutes(to: api.group("files").add(middleware: userJWTAuthenticator))  // Both download and upload are protected

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
private func loadEnvironment(logger: Logger) {
    // First try to load environment-specific file
    let envFile = ".env.\(Environment.current)"
    logger.debug("Attempting to load \(envFile)")
    
    if let contents = try? String(contentsOfFile: envFile, encoding: .utf8) {
        logger.info("Loading environment from \(envFile)")
        loadEnvContents(contents)
        return
    } else {
        logger.warning("Could not load \(envFile)")
    }
    
    // Fall back to .env file
    if let contents = try? String(contentsOfFile: ".env", encoding: .utf8) {
        logger.info("Loading environment from .env")
        loadEnvContents(contents)
    } else {
        logger.warning("Could not load .env file")
    }
}

private func loadEnvContents(_ contents: String) {
    let lines = contents.components(separatedBy: .newlines)
    for line in lines {
        let parts = line.components(separatedBy: "=")
        guard parts.count == 2 else { continue }
        let key = parts[0].trimmingCharacters(in: .whitespaces)
        let value = parts[1].trimmingCharacters(in: .whitespaces)
        setenv(key, value, 1)
    }
}
