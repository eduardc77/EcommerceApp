import Foundation

enum Environment: String {
    case development = "development"
    case staging = "staging"
    case production = "production"

    static var current: Environment {
        guard let environmentString = ProcessInfo.processInfo.environment["APP_ENV"],
              let environment = Environment(rawValue: environmentString.lowercased()) else {
            return .development
        }
        return environment
    }
    
    /// Get environment variable with a default value
    static func get(_ key: String, default defaultValue: String) -> String {
        ProcessInfo.processInfo.environment[key] ?? defaultValue
    }
    
    /// Get environment variable as Int with a default value
    static func getInt(_ key: String, default defaultValue: Int) -> Int {
        if let value = ProcessInfo.processInfo.environment[key],
           let intValue = Int(value) {
            return intValue
        }
        return defaultValue
    }
    
    /// Get environment variable as array with a default value
    static func getArray(_ key: String, default defaultValue: [String]) -> [String] {
        guard let value = ProcessInfo.processInfo.environment[key] else {
            return defaultValue
        }
        let array = value.split(separator: ",").map(String.init)
        return array.isEmpty ? defaultValue : array
    }
    
    var baseURL: String {
        switch self {
        case .development:
            return "http://localhost:8080"
        case .staging:
            return "https://api-staging.yourdomain.com"
        case .production:
            return "https://api.yourdomain.com"
        }
    }
    
    var isProduction: Bool { self == .production }
    var isDevelopment: Bool { self == .development }
    var isStaging: Bool { self == .staging }
}

/// Application configuration from environment variables
struct AppConfig {
    static let environment = Environment.current
    
    // JWT Configuration
    static let jwtSecret: String = {
        let secret = Environment.get("JWT_SECRET", default: "")
        if environment.isProduction && secret.isEmpty {
            fatalError("JWT_SECRET must be set in production environment")
        }
        return secret.isEmpty ? defaultJWTSecret : secret
    }()
    
    private static var defaultJWTSecret: String {
        switch environment {
        case .production:
            return "" // Will trigger the fatal error above
        case .staging:
            return "staging-secret-key-replace-in-production"
        case .development:
            return "default-dev-only-secret"
        }
    }
    
    // CORS Configuration
    static let allowedOrigins: [String] = {
        let origins = Environment.getArray("ALLOWED_ORIGINS", default: defaultAllowedOrigins)
        if environment.isProduction && origins.isEmpty {
            fatalError("ALLOWED_ORIGINS must be set in production environment")
        }
        return origins
    }()
    
    private static var defaultAllowedOrigins: [String] {
        switch environment {
        case .production:
            return []  // Will trigger the fatal error above
        case .staging:
            return ["https://staging.yourdomain.com"]
        case .development:
            return ["localhost:8080", "127.0.0.1:8080"]
        }
    }
    
    // Rate Limiting
    static let requestsPerMinute: Int = {
        let value = Environment.getInt("RATE_LIMIT_PER_MINUTE", default: 0)
        if value <= 0 {
            switch environment {
            case .production:
                return 60  // Stricter in production
            case .staging:
                return 100 // More lenient in staging
            case .development:
                return 1000 // Very lenient in development
            }
        }
        return value
    }()
    
    // Rate Limit Whitelist
    static let rateLimitWhitelist: [String] = {
        let whitelist = Environment.getArray("RATE_LIMIT_WHITELIST", default: [])
        if whitelist.isEmpty {
            switch environment {
            case .production:
                return [] // No whitelist in production by default
            case .staging:
                return ["staging-test-ip"]
            case .development:
                return ["127.0.0.1"]
            }
        }
        return whitelist
    }()
    
    // Database Configuration
    static let databasePath: String = {
        let path = Environment.get("DATABASE_PATH", default: "")
        if !path.isEmpty {
            return path
        }
        switch environment {
        case .production:
            return "production.sqlite"
        case .staging:
            return "staging.sqlite"
        case .development:
            return "dev.sqlite"
        }
    }()
    
    // Logging Configuration
    static let logLevel: String = {
        let level = Environment.get("LOG_LEVEL", default: "")
        if !level.isEmpty {
            return level.lowercased()
        }
        switch environment {
        case .production:
            return "info"
        case .staging, .development:
            return "debug"
        }
    }()
    
    // Server Configuration
    static let serverPort: Int = Environment.getInt("SERVER_PORT", default: 8080)
    static let serverHost: String = Environment.get("SERVER_HOST", default: "127.0.0.1")
} 
