import Foundation

/// Gender options available for users
public enum Gender: String, Codable, CaseIterable, Sendable {
    case notSpecified = ""
    case male = "Male"
    case female = "Female"
    case other = "Other"
    
    /// Display name for the gender
    public var displayName: String {
        switch self {
        case .notSpecified:
            return "Not specified"
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .other:
            return "Other"
        }
    }
} 