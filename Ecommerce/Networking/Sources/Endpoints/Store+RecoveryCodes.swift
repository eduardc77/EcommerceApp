import Foundation

extension Store {
    public enum RecoveryCodes: APIEndpoint {
        case generateRecoveryCodes
        case listRecoveryCodes
        case regenerateRecoveryCodes(password: String)
        case verifyRecoveryCode(code: String, stateToken: String)
        case status
        
        public var path: String {
            switch self {
            case .generateRecoveryCodes:
                return "/mfa/recovery/generate"
            case .listRecoveryCodes:
                return "/mfa/recovery/list"
            case .regenerateRecoveryCodes:
                return "/mfa/recovery/regenerate"
            case .verifyRecoveryCode:
                return "/mfa/recovery/verify"
            case .status:
                return "/mfa/recovery/status"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .generateRecoveryCodes, .regenerateRecoveryCodes, .verifyRecoveryCode:
                return .post
            case .listRecoveryCodes, .status:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .regenerateRecoveryCodes(let password):
                return ["password": password]
            case .verifyRecoveryCode(let code, let stateToken):
                return ["code": code, "state_token": stateToken]
            default:
                return nil
            }
        }
        
        public var headers: [String: String]? { nil }
        
        public var formParams: [String: String]? { nil }
        
        public var requiresAuthorization: Bool {
            switch self {
            case .generateRecoveryCodes, .listRecoveryCodes, .regenerateRecoveryCodes, .status:
                return true
            case .verifyRecoveryCode:
                return false
            }
        }
    }
} 