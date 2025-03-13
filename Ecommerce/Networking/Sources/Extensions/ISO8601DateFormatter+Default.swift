import Foundation

extension ISO8601DateFormatter {
    /// Default formatter configured for the server's date format
    public static let `default`: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    /// Format a date to string using the default formatter
    public static func string(from date: Date) -> String {
        `default`.string(from: date)
    }
    
    /// Parse a string to date using the default formatter
    public static func date(from string: String) -> Date? {
        `default`.date(from: string)
    }
} 