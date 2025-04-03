import Foundation

extension Store {
    public enum TOTP: APIEndpoint {
        case enable
        case verify(code: String)
        case disable(password: String)
        case status
        
        public var path: String {
            switch self {
            case .enable:
                return "/mfa/totp/enable"
            case .verify:
                return "/mfa/totp/verify"
            case .disable:
                return "/mfa/totp/disable"
            case .status:
                return "/mfa/totp/status"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .enable, .verify, .disable:
                return .post
            case .status:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .verify(let code):
                return TOTPVerifyRequest(code: code)
            case .disable(let password):
                return ["password": password]
            default:
                return nil
            }
        }
        
        public var headers: [String: String]? { nil }
        
        public var formParams: [String: String]? { nil }
    }
}

/// Request for verifying a TOTP code during setup
public struct TOTPVerifyRequest: Codable {
    public let code: String
    
    public init(code: String) {
        self.code = code
    }
}
