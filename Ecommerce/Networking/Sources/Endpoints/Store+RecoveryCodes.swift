import Foundation

extension Store {
    public enum RecoveryCodes: APIEndpoint {
        case generateRecoveryCodes
        case listRecoveryCodes
        case regenerateRecoveryCodes(password: String)
        case verifyRecoveryCode(code: String, stateToken: String)
        
        public var path: String {
            switch self {
            case .generateRecoveryCodes:
                return "/auth/mfa/recovery/generate"
            case .listRecoveryCodes:
                return "/auth/mfa/recovery/list"
            case .regenerateRecoveryCodes:
                return "/auth/mfa/recovery/regenerate"
            case .verifyRecoveryCode:
                return "/auth/mfa/recovery/verify"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .generateRecoveryCodes, .regenerateRecoveryCodes, .verifyRecoveryCode:
                return .post
            case .listRecoveryCodes:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .regenerateRecoveryCodes(let password):
                return ["password": password]
            case .verifyRecoveryCode(let code, let stateToken):
                return ["code": code, "stateToken": stateToken]
            default:
                return nil
            }
        }
        
        public var headers: [String: String]? { nil }
        
        public var formParams: [String: String]? { nil }
    }
} 