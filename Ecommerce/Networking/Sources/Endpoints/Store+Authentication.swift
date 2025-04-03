import Foundation

extension Store {
    
    public enum Authentication: APIEndpoint {
        case signIn(request: SignInRequest)
        case signUp(request: SignUpRequest)
        case signOut
        case me
        case refreshToken(_ refreshToken: String)
        case changePassword(request: ChangePasswordRequest)
        case forgotPassword(email: String)
        case resetPassword(request: ResetPasswordRequest)
        case verifyTOTPSignIn(code: String, stateToken: String)
        case verifyEmailMFASignIn(code: String, stateToken: String)
        case resendEmailMFASignIn(stateToken: String)
        case sendEmailMFASignIn(stateToken: String)
        case selectMFAMethod(method: String, stateToken: String)
        case getMFAMethods(stateToken: String?)
        case requestEmailCode(stateToken: String)
        case cancelAuthentication
        case revokeAccessToken(_ token: String)
        case revokeSession(sessionId: String)
        case revokeAllOtherSessions
        case listSessions
        case getUserInfo
        case signInWithGoogle(idToken: String, accessToken: String?)
        case signInWithApple(identityToken: String, authorizationCode: String, fullName: [String: String?]?, email: String?)
        case socialSignIn(provider: String, redirectUri: String, codeChallenge: String, codeChallengeMethod: String, state: String, scope: String?)
        case handleOAuthCallback(code: String, state: String)
        case exchangeCodeForTokens(code: String, codeVerifier: String, redirectUri: String)
        case sendInitialVerificationEmail(stateToken: String, email: String)
        case resendInitialVerificationEmail(stateToken: String, email: String)
        case verifyInitialEmail(code: String, stateToken: String, email: String)
        case getInitialEmailVerificationStatus
        
        public var path: String {
            switch self {
            case .signIn:
                return "/auth/sign-in"
            case .signUp:
                return "/auth/sign-up"
            case .sendInitialVerificationEmail:
                return "/auth/verify-email/send"
            case .resendInitialVerificationEmail:
                return "/auth/verify-email/resend"
            case .verifyInitialEmail:
                return "/auth/verify-email/confirm"
            case .getInitialEmailVerificationStatus:
                return "/auth/verify-email/status"
            case .signOut:
                return "/auth/sign-out"
            case .me:
                return "/auth/me"
            case .refreshToken:
                return "/auth/token/refresh"
            case .changePassword:
                return "/auth/password/change"
            case .forgotPassword:
                return "/auth/password/forgot"
            case .resetPassword:
                return "/auth/password/reset"
            case .verifyTOTPSignIn:
                return "/auth/mfa/totp/verify"
            case .verifyEmailMFASignIn:
                return "/auth/mfa/email/verify"
            case .resendEmailMFASignIn:
                return "/auth/mfa/email/resend"
            case .sendEmailMFASignIn:
                return "/auth/mfa/email/send"
            case .selectMFAMethod:
                return "/auth/mfa/select"
            case .getMFAMethods:
                return "/auth/mfa/methods"
            case .requestEmailCode:
                return "/auth/mfa/email/send"
            case .cancelAuthentication:
                return "/auth/cancel"
            case .revokeAccessToken:
                return "/auth/token/revoke"
            case .revokeSession:
                return "/auth/sessions"
            case .revokeAllOtherSessions:
                return "/auth/sessions/revoke-all"
            case .listSessions:
                return "/auth/sessions"
            case .getUserInfo:
                return "/auth/userinfo"
            case .signInWithGoogle:
                return "/auth/google/sign-in"
            case .signInWithApple:
                return "/auth/apple/sign-in"
            case .socialSignIn:
                return "/auth/social/authorize"
            case .handleOAuthCallback:
                return "/auth/social/callback"
            case .exchangeCodeForTokens:
                return "/auth/social/token"
            }
        }
        
        public var httpMethod: HTTPMethod {
            switch self {
            case .signIn, .signUp, .signOut, .refreshToken, .changePassword,
                 .forgotPassword, .resetPassword, .verifyTOTPSignIn,
                 .verifyEmailMFASignIn, .resendEmailMFASignIn, .sendEmailMFASignIn,
                 .selectMFAMethod, .requestEmailCode, .cancelAuthentication, .revokeAccessToken,
                 .revokeAllOtherSessions, .signInWithGoogle,
                 .signInWithApple, .exchangeCodeForTokens, .sendInitialVerificationEmail,
                 .resendInitialVerificationEmail, .verifyInitialEmail:
                return .post
            case .me, .getMFAMethods, .listSessions, .getUserInfo,
                 .socialSignIn, .handleOAuthCallback, .getInitialEmailVerificationStatus:
                return .get
            case .revokeSession:
                return .delete
            }
        }
        
        public var headers: [String: String]? {
            switch self {
            case .signIn(let request):
                // Convert credentials to Basic Auth header
                let credentials = "\(request.identifier):\(request.password)"
                if let data = credentials.data(using: .utf8) {
                    let base64 = data.base64EncodedString()
                    var headers = ["Authorization": "Basic \(base64)"]
                    // Add X-Token-Expiry header if custom expiry is requested
                    if let expiresIn = request.expiresIn {
                        headers["X-Token-Expiry"] = "\(expiresIn)"
                    }
                    return headers
                }
                return nil
            default:
                return nil
            }
        }
        
        public var queryParams: [String: String]? {
            switch self {
            case .getMFAMethods(let stateToken):
                if let stateToken = stateToken {
                    return ["state_token": stateToken]
                }
                return nil
            case let .socialSignIn(_, redirectUri, codeChallenge, codeChallengeMethod, state, scope):
                var params: [String: String] = [
                    "redirect_uri": redirectUri,
                    "response_type": "code",
                    "code_challenge": codeChallenge,
                    "code_challenge_method": codeChallengeMethod,
                    "state": state
                ]
                if let scope = scope {
                    params["scope"] = scope
                }
                return params
            case .handleOAuthCallback(let code, let state):
                return ["code": code, "state": state]
            default:
                return nil
            }
        }
        
        public var requestBody: Any? {
            switch self {
            case .signIn(let request):
                return request
            case .signUp(let request):
                return request
            case .changePassword(let request):
                return request
            case .forgotPassword(let email):
                return ["email": email]
            case .resetPassword(let request):
                return request
            case let .verifyTOTPSignIn(code, stateToken):
                return ["code": code, "state_token": stateToken]
            case let .verifyEmailMFASignIn(code, stateToken):
                return ["code": code, "state_token": stateToken]
            case let .resendEmailMFASignIn(stateToken):
                return ["state_token": stateToken]
            case let .sendEmailMFASignIn(stateToken):
                return ["state_token": stateToken]
            case let .selectMFAMethod(method, stateToken):
                return ["method": method, "state_token": stateToken]
            case let .requestEmailCode(stateToken):
                return ["state_token": stateToken]
            case let .revokeAccessToken(token):
                return ["token": token]
            case let .revokeSession(sessionId):
                return ["sessionId": sessionId]
            case let .signInWithGoogle(idToken, accessToken):
                var body: [String: String] = ["idToken": idToken]
                if let accessToken = accessToken {
                    body["accessToken"] = accessToken
                }
                return body
            case let .signInWithApple(identityToken, authorizationCode, fullName, email):
                var body: [String: Any] = [
                    "identityToken": identityToken,
                    "authorizationCode": authorizationCode
                ]
                if let fullName = fullName {
                    body["fullName"] = fullName
                }
                if let email = email {
                    body["email"] = email
                }
                return body
            case let .socialSignIn(provider, redirectUri, codeChallenge, codeChallengeMethod, state, scope):
                var body: [String: String] = [
                    "provider": provider,
                    "redirectUri": redirectUri,
                    "codeChallenge": codeChallenge,
                    "codeChallengeMethod": codeChallengeMethod,
                    "state": state
                ]
                if let scope = scope {
                    body["scope"] = scope
                }
                return body
            case let .handleOAuthCallback(code, state):
                return [
                    "code": code,
                    "state": state
                ]
            case let .exchangeCodeForTokens(code, codeVerifier, redirectUri):
                return [
                    "code": code,
                    "codeVerifier": codeVerifier,
                    "redirectUri": redirectUri
                ]
            case let .sendInitialVerificationEmail(stateToken, email):
                return ["state_token": stateToken, "email": email]
            case let .resendInitialVerificationEmail(stateToken, email):
                return ["state_token": stateToken, "email": email]
            case let .verifyInitialEmail(code, stateToken, email):
                return ["code": code, "state_token": stateToken, "email": email]
            case .getInitialEmailVerificationStatus:
                return nil
            case let .refreshToken(refreshToken):
                return ["refresh_token": refreshToken]
            default:
                return nil
            }
        }
        
        public var formParams: [String: String]? { nil }
    }
}
