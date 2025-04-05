import Networking

enum MFAOption: Identifiable {
        case totp
        case email
        case recoveryCode
        
        var id: String {
            switch self {
            case .totp: return "totp"
            case .email: return "email"
            case .recoveryCode: return "recovery-code"
            }
        }
        
        var title: String {
            switch self {
            case .totp: return "Authenticator App"
            case .email: return "Email"
            case .recoveryCode: return "Recovery Code"
            }
        }
        
        var subtitle: String {
            switch self {
            case .totp: return "Use your authenticator app to generate a code"
            case .email: return "Receive a verification code via email"
            case .recoveryCode: return "Use a backup code if you can't access other methods"
            }
        }
        
        var icon: String {
            switch self {
            case .totp: return "key.fill"
            case .email: return "envelope.fill"
            case .recoveryCode: return "key.horizontal.fill"
            }
        }
        
        var method: MFAMethod {
            switch self {
            case .totp: return .totp
            case .email: return .email
            case .recoveryCode: return .recoveryCode
            }
        }
    }
