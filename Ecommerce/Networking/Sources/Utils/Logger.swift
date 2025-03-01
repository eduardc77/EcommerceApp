import Foundation
import OSLog

extension Logger {
    /// Using your bundle identifier is a great way to ensure a unique identifier.
    private static let subsystem = Bundle.main.bundleIdentifier!
    
    static let networking = Logger(subsystem: subsystem, category: "networking")
    
    static func logRequest(_ request: URLRequest) {
        guard let url = request.url else { return }
        networking.info("Request URL: \(url.absoluteString, privacy: .public)")
        if let headers = request.allHTTPHeaderFields {
            networking.info("Request Headers: \(sanitize(headers), privacy: .private)")
        }
        if let body = request.httpBody, !isSensitiveData(request: request) {
            networking.info("Request Body: \(String(data: body, encoding: .utf8) ?? "unknown", privacy: .private)")
        }
    }
    
    static func logResponse(_ response: URLResponse, data: Data) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        networking.info("Response URL: \(httpResponse.url?.absoluteString ?? "unknown", privacy: .public)")
        networking.info("Response Status Code: \(httpResponse.statusCode, privacy: .public)")
        networking.info("Response Headers: \(sanitize(httpResponse.allHeaderFields), privacy: .private)")
        if !isSensitiveData(response: response) {
            networking.info("Response Data: \(String(data: data, encoding: .utf8) ?? "unknown", privacy: .private)")
        }
    }
    
    private static func isSensitiveData(request: URLRequest) -> Bool {
        // Add logic to determine if the request contains sensitive data
        if let url = request.url?.absoluteString {
            if url.contains("/login") || url.contains("/refresh-token") {
                return true
            }
        }
        if let headers = request.allHTTPHeaderFields {
            if headers.keys.contains("Authorization") {
                return true
            }
        }
        return false
    }
    
    private static func isSensitiveData(response: URLResponse) -> Bool {
        // Add logic to determine if the response contains sensitive data
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return true
            }
            if let headers = httpResponse.allHeaderFields as? [String: String] {
                if headers.keys.contains("Set-Cookie") {
                    return true
                }
            }
        }
        return false
    }
    
    private static func sanitize(_ headers: [String: String]) -> String {
        var sanitizedHeaders = headers
        if let _ = sanitizedHeaders["Authorization"] {
            sanitizedHeaders["Authorization"] = "REDACTED"
        }
        return sanitizedHeaders.description
    }
    
    private static func sanitize(_ headers: [AnyHashable: Any]) -> String {
        var sanitizedHeaders = headers
        if let _ = sanitizedHeaders["Authorization"] {
            sanitizedHeaders["Authorization"] = "REDACTED"
        }
        return sanitizedHeaders.description
    }
}
