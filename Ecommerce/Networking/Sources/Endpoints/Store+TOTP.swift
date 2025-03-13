import Foundation

extension Store {
    public enum TOTP: APIEndpoint {
        case setup
        case verify(code: String)
        case enable(code: String)
        case disable(code: String)
        case status
        
        public var path: String {
            switch self {
            case .setup:
                return "/auth/totp/setup"
            case .verify:
                return "/auth/totp/verify"
            case .enable:
                return "/auth/totp/enable"
            case .disable:
                return "/auth/totp/disable"
            case .status:
                return "/auth/totp/status"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .setup, .verify, .enable:
                return .post
            case .disable:
                return .delete
            case .status:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .verify(let code), .enable(let code), .disable(let code):
                return ["code": code]
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
} 