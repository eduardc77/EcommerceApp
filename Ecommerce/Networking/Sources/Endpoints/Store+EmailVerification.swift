import Foundation

public extension Store {
    enum EmailVerification: APIEndpoint {
        case status
        case sendCode
        case verify(code: String)
        case verifyInitial(email: String, code: String)
        case resendVerification(email: String)
        case disable
        
        public var path: String {
            switch self {
            case .status:
                return "/email-verification/status"
            case .sendCode:
                return "/email-verification/send-code"
            case .verify:
                return "/email-verification/verify"
            case .verifyInitial:
                return "/email-verification/verify-email"
            case .resendVerification:
                return "/email-verification/resend-verification"
            case .disable:
                return "/email-verification/disable"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .status:
                return .get
            case .disable:
                return .delete
            default:
                return .post
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .verify(let code):
                return ["code": code]
            case .verifyInitial(let email, let code):
                return ["email": email, "code": code]
            case .resendVerification(let email):
                return ["email": email]
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
} 