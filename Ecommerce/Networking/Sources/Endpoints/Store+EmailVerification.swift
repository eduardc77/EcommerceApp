import Foundation

public extension Store {
    enum EmailVerification: APIEndpoint {
        case enableEmailMFA
        case verifyEmailMFA(code: String, email: String)
        case disableEmailMFA(password: String)
        case getEmailMFAStatus
        case resendEmailMFACode
        
        public var path: String {
            switch self {
            case .enableEmailMFA:
                return "/mfa/email/enable"
            case .verifyEmailMFA:
                return "/mfa/email/verify"
            case .disableEmailMFA:
                return "/mfa/email/disable"
            case .getEmailMFAStatus:
                return "/mfa/email/status"
            case .resendEmailMFACode:
                return "/mfa/email/resend"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .getEmailMFAStatus:
                return .get
            default:
                return .post
            }
        }
        
        public var headers: [String: String]? {
            return nil
        }
        
        public var queryParams: [String: String]? {
            return nil
        }
        
        public var requestBody: Any? {
            switch self {
            case .verifyEmailMFA(let code, let email):
                return ["code": code, "email": email]
            case .disableEmailMFA(let password):
                return ["password": password]
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
} 
