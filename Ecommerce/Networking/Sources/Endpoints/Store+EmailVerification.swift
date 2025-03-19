import Foundation

public extension Store {
    enum EmailVerification: APIEndpoint {
        case initialStatus
        case verifyInitial(email: String, code: String)
        case resend(email: String)
        case setup2FA
        case verify2FA(code: String)
        case disable2FA(code: String)
        case get2FAStatus
        
        public var path: String {
            switch self {
            case .initialStatus:
                return "/auth/email/2fa/status"
            case .verifyInitial:
                return "/auth/email/verify-initial"
            case .resend:
                return "/auth/email/resend"
            case .setup2FA:
                return "/auth/email/2fa/setup"
            case .verify2FA:
                return "/auth/email/2fa/verify"
            case .disable2FA:
                return "/auth/email/2fa/disable"
            case .get2FAStatus:
                return "/auth/email/2fa/status"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .initialStatus, .get2FAStatus:
                return .get
            case .disable2FA:
                return .delete
            default:
                return .post
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .verify2FA(let code):
                return ["code": code]
            case .verifyInitial(let email, let code):
                return [
                    "email": email,
                    "code": code
                ]
            case .resend(let email):
                return ["email": email]
            default:
                return nil
            }
        }
        
        public var headers: [String: String]? {
            switch self {
            case .disable2FA(let code):
                return ["x-email-code": code]
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
} 
