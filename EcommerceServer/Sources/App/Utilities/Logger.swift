import Foundation
import Logging

// MARK: - LoggerMetadata
/// Struct to hold additional context for logs
struct LogMetadata {
    /// Request ID for correlating log messages
    static var requestId: String?
    
    /// Current user ID if available
    static var userId: String?
    
    /// Reset all metadata
    static func reset() {
        requestId = nil
        userId = nil
    }
}

// Static logger implementation for the backend
extension Logger {
    // Pre-configured loggers for different categories with appropriate log levels
    private static var _auth: Logger = {
        var logger = Logger(label: "app.auth")
        #if DEBUG
        logger.logLevel = .debug
        #else
        logger.logLevel = .info
        #endif
        return logger
    }()
    
    private static var _database: Logger = {
        var logger = Logger(label: "app.database")
        #if DEBUG
        logger.logLevel = .debug
        #else
        logger.logLevel = .info
        #endif
        return logger
    }()
    
    private static var _api: Logger = {
        var logger = Logger(label: "app.api")
        #if DEBUG
        logger.logLevel = .debug
        #else
        logger.logLevel = .info
        #endif
        return logger
    }()
    
    private static var _server: Logger = {
        var logger = Logger(label: "app.server")
        #if DEBUG
        logger.logLevel = .debug
        #else
        logger.logLevel = .info
        #endif
        return logger
    }()
    
    // Public getters/setters for the loggers
    static var auth: Logger {
        get { return _auth }
        set { _auth = newValue }
    }
    
    static var database: Logger {
        get { return _database }
        set { _database = newValue }
    }
    
    static var api: Logger {
        get { return _api }
        set { _api = newValue }
    }
    
    static var server: Logger {
        get { return _server }
        set { _server = newValue }
    }
    
    // MARK: - Enhanced Logging Methods
    
    /// Log with added metadata context
    static func log(level: Logger.Level, message: String, category: Logger = server, metadata: [String: String] = [:]) {
        var logger = category
        var combinedMetadata = metadata
        
        // Add correlation ID if available
        if let requestId = LogMetadata.requestId {
            combinedMetadata["request_id"] = requestId
        }
        
        // Add user context if available
        if let userId = LogMetadata.userId {
            combinedMetadata["user_id"] = userId
        }
        
        // Add metadata to logger
        for (key, value) in combinedMetadata {
            logger[metadataKey: key] = .string(value)
        }
        
        // Log the message
        logger.log(level: level, "\(message)")
    }
    
    // Request logging
    static func logRequest(_ request: URLRequest) {
        guard let url = request.url else { return }
        log(level: .info, message: "Request URL: \(url.absoluteString)")
        
        if let headers = request.allHTTPHeaderFields {
            log(level: .info, message: "Request Headers: \(sanitize(headers))")
        }
        
        if let body = request.httpBody, !isSensitiveData(request: request) {
            if let bodyString = String(data: body, encoding: .utf8) {
                log(level: .info, message: "Request Body: \(sanitizeJson(bodyString))")
            }
        }
    }
    
    // Response logging
    static func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        log(level: .info, message: "Response URL: \(httpResponse.url?.absoluteString ?? "unknown")")
        log(level: .info, message: "Response Status Code: \(httpResponse.statusCode)")
        log(level: .info, message: "Response Headers: \(sanitize(httpResponse.allHeaderFields))")
        
        if !isSensitiveData(response: response) {
            if let bodyString = String(data: data, encoding: .utf8) {
                log(level: .info, message: "Response Data: \(sanitizeJson(bodyString))")
            }
        }
    }
    
    // MARK: - Security Methods
    
    // Enhanced sensitive data detection for requests
    private static func isSensitiveData(request: URLRequest) -> Bool {
        if let url = request.url?.absoluteString.lowercased() {
            // Sensitive paths
            if url.contains("/login") || 
               url.contains("/refresh-token") || 
               url.contains("/auth") || 
               url.contains("/password") ||
               url.contains("/token") {
                return true
            }
        }
        
        if let headers = request.allHTTPHeaderFields {
            // Sensitive headers
            for key in headers.keys {
                if key.lowercased().contains("authorization") || 
                   key.lowercased().contains("cookie") || 
                   key.lowercased().contains("token") || 
                   key.lowercased().contains("secret") {
                    return true
                }
            }
        }
        
        // Check request body for sensitive fields
        if let body = request.httpBody, 
           let bodyString = String(data: body, encoding: .utf8)?.lowercased() {
            if bodyString.contains("password") || 
               bodyString.contains("token") || 
               bodyString.contains("secret") || 
               bodyString.contains("credit") ||
               bodyString.contains("auth") {
                return true
            }
        }
        
        return false
    }
    
    // Enhanced sensitive data detection for responses
    private static func isSensitiveData(response: URLResponse) -> Bool {
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return true
            }
            
            if let url = httpResponse.url?.absoluteString.lowercased() {
                if url.contains("/login") || 
                   url.contains("/refresh-token") || 
                   url.contains("/auth") || 
                   url.contains("/password") ||
                   url.contains("/token") {
                    return true
                }
            }
            
            if let headers = httpResponse.allHeaderFields as? [String: String] {
                for key in headers.keys {
                    if key.lowercased().contains("authorization") || 
                       key.lowercased().contains("cookie") || 
                       key.lowercased().contains("token") || 
                       key.lowercased().contains("secret") || 
                       key.lowercased().contains("set-cookie") {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // Sanitize request headers
    private static func sanitize(_ headers: [String: String]) -> String {
        var sanitizedHeaders = headers
        let sensitiveKeys = ["authorization", "cookie", "set-cookie", "token", "secret"]
        
        for (key, _) in headers {
            if sensitiveKeys.contains(where: { key.lowercased().contains($0) }) {
                sanitizedHeaders[key] = "REDACTED"
            }
        }
        
        return sanitizedHeaders.description
    }
    
    // Sanitize response headers
    private static func sanitize(_ headers: [AnyHashable: Any]) -> String {
        var sanitizedHeaders = headers
        let sensitiveKeys = ["authorization", "cookie", "set-cookie", "token", "secret"]
        
        for (key, _) in headers {
            if let keyString = key as? String, 
               sensitiveKeys.contains(where: { keyString.lowercased().contains($0) }) {
                sanitizedHeaders[key] = "REDACTED"
            }
        }
        
        return sanitizedHeaders.description
    }
    
    // Sanitize JSON data
    private static func sanitizeJson(_ jsonString: String) -> String {
        // Simple approach to redact common sensitive fields in JSON
        let sensitiveFields = ["password", "token", "secret", "authorization", 
                              "creditCard", "cvv", "ssn", "socialSecurity"]
        
        var result = jsonString
        for field in sensitiveFields {
            // Match JSON patterns like "field": "value" with regex
            let pattern = "\"(\(field)[^\"]*?)\"\\s*:\\s*\"[^\"]*?\""
            result = result.replacingOccurrences(
                of: pattern, 
                with: "\"$1\": \"REDACTED\"", 
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return result
    }
    
    // MARK: - Lifecycle Methods
    
    /// Generate a new request ID for correlation
    static func generateRequestId() -> String {
        let requestId = UUID().uuidString
        LogMetadata.requestId = requestId
        return requestId
    }
    
    /// Set the current user ID for logging context
    static func setUserId(_ userId: String?) {
        LogMetadata.userId = userId
    }
    
    /// Clear log context at the end of a request cycle
    static func clearContext() {
        LogMetadata.reset()
    }
} 
