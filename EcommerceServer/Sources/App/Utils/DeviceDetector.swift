import Foundation

/// Utility class for detecting device information from User-Agent strings
enum DeviceDetector {
    /// Extract a human-readable device name from a User-Agent string
    /// - Parameter userAgent: The User-Agent string from the HTTP request
    /// - Returns: A human-readable device name, or "Unknown Device" if unable to determine
    static func getDeviceName(from userAgent: String) -> String {
        let userAgent = userAgent.lowercased()
        
        // Check for mobile devices first
        if userAgent.contains("iphone") {
            return "iPhone"
        } else if userAgent.contains("ipad") {
            return "iPad"
        } else if userAgent.contains("android") {
            if userAgent.contains("mobile") {
                return "Android Phone"
            }
            return "Android Tablet"
        }
        
        // Check for desktop browsers
        if userAgent.contains("macintosh") || userAgent.contains("mac os x") {
            return "Mac"
        } else if userAgent.contains("windows") {
            return "Windows PC"
        } else if userAgent.contains("linux") {
            return "Linux"
        }
        
        // If we can't determine the device, try to at least get the browser
        if userAgent.contains("firefox") {
            return "Firefox Browser"
        } else if userAgent.contains("chrome") {
            return "Chrome Browser"
        } else if userAgent.contains("safari") {
            return "Safari Browser"
        } else if userAgent.contains("opera") {
            return "Opera Browser"
        } else if userAgent.contains("edge") {
            return "Edge Browser"
        }
        
        return "Unknown Device"
    }
} 