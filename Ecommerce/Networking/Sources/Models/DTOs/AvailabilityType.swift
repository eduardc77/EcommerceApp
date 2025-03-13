/// Type of availability check for user registration
public enum AvailabilityType: Sendable {
    case username(String)
    case email(String)
    
    var queryItem: (key: String, value: String) {
        switch self {
        case .username(let value): return ("username", value)
        case .email(let value): return ("email", value)
        }
    }
} 
