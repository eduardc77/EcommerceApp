import Foundation

extension Store {
    
    public enum Authentication: APIEndpoint {
        case login(dto: LoginRequest)
        case register(dto: CreateUserRequest)
        case refreshToken(_ token: String)
        case logout
        case me
        case changePassword(current: String, new: String)
        case requestEmailCode
        case forgotPassword(email: String)
        case resetPassword(email: String, code: String, newPassword: String)
        case verifyTOTPLogin(code: String, tempToken: String)
        case verifyEmail2FALogin(code: String, tempToken: String)

        public var path: String {
            switch self {
                case .login:
                    return "/auth/login"
                case .register:
                    return "/auth/register"
                case .refreshToken:
                    return "/auth/refresh"
                case .logout:
                    return "/auth/logout"
                case .me:
                    return "/auth/me"
                case .changePassword:
                    return "/auth/change-password"
                case .requestEmailCode:
                    return "/auth/email-code"
                case .forgotPassword:
                    return "/auth/forgot-password"
                case .resetPassword:
                    return "/auth/reset-password"
                case .verifyTOTPLogin:
                    return "/auth/login/verify-totp"
                case .verifyEmail2FALogin:
                    return "/auth/login/verify-email"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
                case .login, .register, .refreshToken, .logout, .changePassword,
                     .requestEmailCode, .forgotPassword, .resetPassword, .verifyTOTPLogin,
                     .verifyEmail2FALogin:
                    return .post
                case .me:
                    return .get
            }
        }
        
        public var headers: [String: String]? {
            switch self {
                case .login(let dto):
                    var headers: [String: String] = [:]
                    
                    // Add Basic Auth header
                    let credentials = "\(dto.identifier):\(dto.password)".data(using: .utf8)?.base64EncodedString() ?? ""
                    headers["Authorization"] = "Basic \(credentials)"
                    
                    // Add 2FA headers if provided
                    if let totpCode = dto.totpCode {
                        headers["X-TOTP-Code"] = totpCode
                    }
                    if let emailCode = dto.emailCode {
                        headers["X-Email-Code"] = emailCode
                    }
                    
                    return headers
                    
                case .refreshToken(let token):
                    return ["Authorization": "Bearer \(token)"]
                default:
                    return nil
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .login:
                return nil  // Credentials are in Authorization header
            case .register(let dto):
                return dto
            case .refreshToken(let token):
                return ["refreshToken": token]
            case .changePassword(let current, let new):
                return [
                    "currentPassword": current,
                    "newPassword": new
                ]
            case .forgotPassword(let email):
                return ["email": email]
            case .resetPassword(let email, let code, let newPassword):
                return [
                    "email": email,
                    "code": code,
                    "newPassword": newPassword
                ]
            case .verifyTOTPLogin(let code, let tempToken):
                return [
                    "code": code,
                    "tempToken": tempToken
                ]
            case .verifyEmail2FALogin(let code, let tempToken):
                return [
                    "code": code,
                    "tempToken": tempToken
                ]
            case .logout, .me, .requestEmailCode:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
}
