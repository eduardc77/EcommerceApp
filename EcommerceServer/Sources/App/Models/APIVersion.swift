import Foundation

/// Represents the API versions supported by the application
public enum APIVersion: String {
    case v1 = "v1"
    
    /// The current active version of the API
    public static let current: APIVersion = .v1
    
    /// Returns the path component for routing
    public var pathComponent: String {
        return self.rawValue
    }
} 
