import Foundation

extension Store {
    
    public enum Authentication: APIEndpoint {
        case login(dto: LoginRequest)
        case register(dto: CreateUserRequest)
        case refreshToken(_ token: String)
        case logout
        case me
        case changePassword(current: String, new: String)
        case requestEmailCode(tempToken: String)
        case forgotPassword(email: String)
        case resetPassword(email: String, code: String, newPassword: String)
        case verifyTOTPLogin(code: String, tempToken: String)
        case verifyEmail2FALogin(code: String, tempToken: String)
        case socialLogin(provider: String, params: [String: Any])

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
                case .socialLogin:
                    return "/auth/social/login"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
                case .login, .register, .refreshToken, .logout, .changePassword,
                     .requestEmailCode, .forgotPassword, .resetPassword, .verifyTOTPLogin,
                     .verifyEmail2FALogin, .socialLogin:
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
                case .requestEmailCode(let tempToken):
                    return ["Authorization": "Bearer \(tempToken)"]
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
            case .socialLogin(let provider, let params):
                // Construct provider-specific parameters
                var payload: [String: Any] = [:]
                
                switch provider {
                case "google":
                    guard let idToken = params["idToken"] as? String else {
                        break
                    }
                    
                    payload = [
                        "idToken": idToken,
                        "accessToken": params["accessToken"] as? String ?? ""
                    ]
                case "apple":
                    guard let identityToken = params["identityToken"] as? String,
                          let authorizationCode = params["authorizationCode"] as? String else {
                        break
                    }
                    
                    payload = [
                        "identityToken": identityToken,
                        "authorizationCode": authorizationCode
                    ]
                    
                    // Add optional parameters if available
                    if let fullName = params["fullName"] as? [String: String?] {
                        payload["fullName"] = fullName
                    }
                    
                    if let email = params["email"] as? String {
                        payload["email"] = email
                    }
                default:
                    break
                }
                
                return payload
            case .requestEmailCode:
                return nil  // No body needed
            case .logout, .me:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
}
