import Logging

/// Provides access to application logging
enum AppLogger {
    /// Global logger for use outside of request context
    private static var globalLogger: Logger = {
        var logger = Logger(label: "app.global")
        #if DEBUG
        logger.logLevel = .debug
        #else
        logger.logLevel = .info
        #endif
        return logger
    }()
    
    /// Access the global logger
    static var global: Logger {
        globalLogger
    }
    
    /// Configure the global logger
    static func configure(logLevel: Logger.Level? = nil) {
        if let logLevel = logLevel {
            globalLogger.logLevel = logLevel
        }
    }
} 
