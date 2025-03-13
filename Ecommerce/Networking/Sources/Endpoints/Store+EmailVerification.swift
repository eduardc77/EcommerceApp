import Foundation

extension Store {
    public enum EmailVerification: APIEndpoint {
        case verifyInitial(code: String)
        case resend(email: String)
        case sendCode
        case verify(code: String)
        case disable(code: String)
        case status
        
        public var path: String {
            switch self {
            case .verifyInitial:
                return "/auth/email/verify-email"
            case .resend:
                return "/auth/email/resend-verification"
            case .sendCode:
                return "/auth/email/send-code"
            case .verify:
                return "/auth/email/verify"
            case .disable:
                return "/auth/email/disable"
            case .status:
                return "/auth/email/status"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .verifyInitial, .resend, .sendCode, .verify:
                return .post
            case .disable:
                return .delete
            case .status:
                return .get
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .verifyInitial(let code), .verify(let code):
                return ["code": code]
            case .resend(let email):
                return ["email": email]
            case .disable(let code):
                return nil  // Code goes in header
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? {
            switch self {
            case .disable(let code):
                return ["x-email-code": code]
            default:
                return nil
            }
        }
    }
} 