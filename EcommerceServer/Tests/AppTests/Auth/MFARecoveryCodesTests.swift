@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import HummingbirdOTP

@Suite("MFA Recovery Code Tests")
struct MFARecoveryCodesTests {
    @Test("Can generate and use recovery codes")
    func testGenerateAndUseRecoveryCodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Sign up test user
            let requestBody = TestSignUpRequest(
                username: "recovery_test_123",
                displayName: "Recovery Test User",
                email: "recovery_test_123@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)
            
            // Sign in to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Enable TOTP (required for recovery codes)
            let setupResponseData = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPEnableResponse.self, from: response.body)
            }
            
            // Verify TOTP verify
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Get fresh tokens after enabling TOTP
            let signInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.username, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Complete TOTP verification
            let totpCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            let freshAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: signInResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }
            
            // Generate recovery codes with fresh token
            let recoveryCodesResponse = try await client.execute(
                uri: "/api/v1/mfa/recovery/generate",
                method: .post,
                auth: .bearer(freshAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .created)
                let codesResponse = try JSONDecoder().decode(RecoveryCodesResponse.self, from: response.body)
                #expect(codesResponse.codes.count == 10) // Default number of codes
                #expect(!codesResponse.codes[0].isEmpty)
                return codesResponse
            }
            
            // List recovery codes
            try await client.execute(
                uri: "/api/v1/mfa/recovery/list",
                method: .get,
                auth: .bearer(freshAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let statusResponse = try JSONDecoder().decode(RecoveryCodesStatusResponse.self, from: response.body)
                #expect(statusResponse.totalCodes == 10)
                #expect(statusResponse.usedCodes == 0)
                #expect(statusResponse.validCodes == 10)
                #expect(!statusResponse.shouldRegenerate)
            }
            
            // Sign in to get state token for recovery code use
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_test_123", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Use recovery code to authenticate
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/mfa/recovery/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RecoveryCodeVerifyRequest(
                        code: recoveryCodesResponse.codes[0],
                        stateToken: mfaSignInResponse.stateToken!
                    ),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }
            
            // Verify code is now marked as used
            try await client.execute(
                uri: "/api/v1/mfa/recovery/list",
                method: .get,
                auth: .bearer(finalAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let statusResponse = try JSONDecoder().decode(RecoveryCodesStatusResponse.self, from: response.body)
                #expect(statusResponse.usedCodes == 1)
                #expect(statusResponse.validCodes == 9)
            }
        }
    }
    
    @Test("Cannot use recovery codes without MFA enabled")
    func testCannotUseRecoveryCodesWithoutMFA() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Sign up test user without MFA
            let requestBody = TestSignUpRequest(
                username: "recovery_no_mfa",
                displayName: "Recovery No MFA User",
                email: "recovery_no_mfa@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)
            
            // Sign in to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_no_mfa", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Try to generate recovery codes without MFA
            try await client.execute(
                uri: "/api/v1/mfa/recovery/generate",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .badRequest)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("MFA must be enabled"))
            }
        }
    }
    
    @Test("Cannot reuse recovery codes")
    func testCannotReuseRecoveryCodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Sign up test user
            let requestBody = TestSignUpRequest(
                username: "recovery_reuse",
                displayName: "Recovery Reuse Test",
                email: "recovery_reuse@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)
            
            // Sign in and setup TOTP
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_reuse", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Enable TOTP
            let setupResponseData = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPEnableResponse.self, from: response.body)
            }
            
            // Verify TOTP setup
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Get fresh tokens after enabling TOTP
            let freshAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.username, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Complete TOTP verification
            let totpCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            let verifyAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: freshAuthResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }
            
            // Generate recovery codes with fresh token
            let recoveryCodesResponse = try await client.execute(
                uri: "/api/v1/mfa/recovery/generate",
                method: .post,
                auth: .bearer(verifyAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(RecoveryCodesResponse.self, from: response.body)
            }
            
            // Sign in to get state token
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_reuse", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                return authResponse
            }
            
            // Use recovery code first time to authenticate
            let recoveryCodesAuthResponse = try await client.execute(
                uri: "/api/v1/mfa/recovery/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RecoveryCodeVerifyRequest(
                        code: recoveryCodesResponse.codes[0],
                        stateToken: mfaSignInResponse.stateToken!
                    ),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }
            
            // Sign out
            try await client.execute(
                uri: "/api/v1/auth/sign-out",
                method: .post,
                auth: .bearer(recoveryCodesAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .noContent)
            }
            
            // Sign in again to get new state token
            let secondMfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_reuse", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                return authResponse
            }
            
            // Try to use same code again with new state token
            try await client.execute(
                uri: "/api/v1/mfa/recovery/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RecoveryCodeVerifyRequest(
                        code: recoveryCodesResponse.codes[0],
                        stateToken: secondMfaSignInResponse.stateToken!
                    ),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .badRequest)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid or expired recovery code"))
            }
        }
    }
    
    @Test("Can regenerate recovery codes")
    func testRegenerateRecoveryCodes() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Sign up test user
            let requestBody = TestSignUpRequest(
                username: "recovery_regen",
                displayName: "Recovery Regenerate Test",
                email: "recovery_regen@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)
            
            // Sign in and setup TOTP
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_regen", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Enable TOTP
            let setupResponseData = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPEnableResponse.self, from: response.body)
            }
            
            // Verify TOTP setup
            let validCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(TOTPVerifyRequest(code: validCode), allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Get fresh tokens after enabling TOTP
            let freshAuthResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.username, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Complete TOTP verification
            let totpCode = try TOTP.generateTestCode(from: setupResponseData.secret)
            let verifyAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: freshAuthResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }
            
            // Generate initial recovery codes
            let initialCodesResponse = try await client.execute(
                uri: "/api/v1/mfa/recovery/generate",
                method: .post,
                auth: .bearer(verifyAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .created)
                return try JSONDecoder().decode(RecoveryCodesResponse.self, from: response.body)
            }
            
            // Regenerate codes with password verification
            let newCodesResponse = try await client.execute(
                uri: "/api/v1/mfa/recovery/regenerate",
                method: .post,
                auth: .bearer(verifyAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    RegenerateCodesRequest(password: "P@th3r#Bk9$mN"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .created)
                let codesResponse = try JSONDecoder().decode(RecoveryCodesResponse.self, from: response.body)
                #expect(codesResponse.codes.count == 10)
                #expect(codesResponse.codes != initialCodesResponse.codes) // New codes should be different
                return codesResponse
            }
            
            // Verify old codes are invalidated
            let mfaSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_regen", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                return authResponse
            }
            
            // Try to use old code
            try await client.execute(
                uri: "/api/v1/mfa/recovery/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RecoveryCodeVerifyRequest(
                        code: initialCodesResponse.codes[0],
                        stateToken: mfaSignInResponse.stateToken!
                    ),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .badRequest)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid or expired recovery code"))
            }
            
            // Verify new code works
            try await client.execute(
                uri: "/api/v1/mfa/recovery/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    RecoveryCodeVerifyRequest(
                        code: newCodesResponse.codes[0],
                        stateToken: mfaSignInResponse.stateToken!
                    ),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
            }
        }
    }
    
    @Test("Recovery codes are managed correctly when enabling/disabling MFA methods")
    func testRecoveryCodesManagement() async throws {
        let app = try await buildApplication(TestAppArguments())
        try await app.test(.router) { client in
            // Sign up test user
            let requestBody = TestSignUpRequest(
                username: "recovery_test_user",
                displayName: "Recovery Test User",
                email: "recovery_test@example.com",
                password: "P@th3r#Bk9$mN",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            let signUpResponse = try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Complete email verification
            try await client.completeEmailVerification(email: requestBody.email, stateToken: signUpResponse.stateToken!)
            
            // Sign in to get access token
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: "recovery_test_user", password: "P@th3r#Bk9$mN")
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Check initial recovery codes status (should be disabled with no codes)
            try await client.execute(
                uri: "/api/v1/mfa/recovery/status",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(RecoveryMFAStatusResponse.self, from: response.body)
                #expect(!status.enabled)
                #expect(!status.hasValidCodes)
            }
            
            // Enable TOTP MFA
            let totpSetupResponse = try await client.execute(
                uri: "/api/v1/mfa/totp/enable",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(TOTPEnableResponse.self, from: response.body)
            }
            
            // Verify TOTP setup
            let setupCode = try TOTP.generateTestCode(from: totpSetupResponse.secret)
            _ = try await client.execute(
                uri: "/api/v1/mfa/totp/verify",
                method: .post,
                auth: .bearer(authResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerifyRequest(code: setupCode),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let verifyResponse = try JSONDecoder().decode(TOTPVerifyResponse.self, from: response.body)
                #expect(verifyResponse.success)
                #expect(verifyResponse.recoveryCodes != nil)
                #expect(!verifyResponse.recoveryCodes!.isEmpty)
                return verifyResponse
            }
            
            // Get fresh tokens after enabling TOTP
            let signInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.username, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_TOTP_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Complete TOTP verification for sign in
            let totpCode = try TOTP.generateTestCode(from: totpSetupResponse.secret)
            let freshAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/totp/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    TOTPVerificationRequest(stateToken: signInResponse.stateToken!, code: totpCode),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_SUCCESS)
                #expect(authResponse.accessToken != nil)
                return authResponse
            }
            
            // Check recovery codes status (should be enabled with valid codes)
            try await client.execute(
                uri: "/api/v1/mfa/recovery/status",
                method: .get,
                auth: .bearer(freshAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(RecoveryMFAStatusResponse.self, from: response.body)
                #expect(status.enabled)
                #expect(status.hasValidCodes)
            }
            
            // Enable Email MFA (should not generate new recovery codes)
            let _ = try await client.execute(
                uri: "/api/v1/mfa/email/enable",
                method: .post,
                auth: .bearer(freshAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Verify Email MFA
            try await client.execute(
                uri: "/api/v1/mfa/email/verify",
                method: .post,
                auth: .bearer(freshAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailVerifyRequest(email: requestBody.email, code: "123456"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let verifyResponse = try JSONDecoder().decode(EmailMFAVerifyResponse.self, from: response.body)
                #expect(verifyResponse.success)
                #expect(verifyResponse.recoveryCodes == nil)
            }
            
            // Get fresh tokens after enabling Email MFA
            let finalSignInResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.username, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Test MFA selection with TOTP method
            let _ = try await client.execute(
                uri: "/api/v1/auth/mfa/select",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    MFASelectionRequest(stateToken: finalSignInResponse.stateToken!, method: .email),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_MFA_EMAIL_REQUIRED)
                #expect(authResponse.stateToken != nil)
                return authResponse
            }
            
            // Send verification code for MFA sign-in
            try await client.execute(
                uri: "/api/v1/auth/mfa/email/send",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    ["state_token": finalSignInResponse.stateToken!],
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
            }
            
            // Complete Email MFA verification
            let finalAuthResponse = try await client.execute(
                uri: "/api/v1/auth/mfa/email/verify",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(
                    EmailSignInVerifyRequest(stateToken: finalSignInResponse.stateToken!, code: "123456"),
                    allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Disable TOTP MFA (should keep recovery codes since email MFA is still enabled)
            try await client.execute(
                uri: "/api/v1/mfa/totp/disable",
                method: .post,
                auth: .bearer(finalAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    DisableTOTPRequest(password: "P@th3r#Bk9$mN"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Check recovery codes status (should still be enabled with valid codes)
            try await client.execute(
                uri: "/api/v1/mfa/recovery/status",
                method: .get,
                auth: .bearer(finalAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(RecoveryMFAStatusResponse.self, from: response.body)
                #expect(status.enabled)
                #expect(status.hasValidCodes)
            }
            
            // Disable Email MFA (should delete recovery codes since no MFA methods remain)
            try await client.execute(
                uri: "/api/v1/mfa/email/disable",
                method: .post,
                auth: .bearer(finalAuthResponse.accessToken!),
                body: JSONEncoder().encodeAsByteBuffer(
                    DisableEmailMFARequest(password: "P@th3r#Bk9$mN"),
                    allocator: ByteBufferAllocator()
                )
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Check recovery codes status (should be disabled with no valid codes)
            try await client.execute(
                uri: "/api/v1/mfa/recovery/status",
                method: .get,
                auth: .bearer(finalAuthResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let status = try JSONDecoder().decode(RecoveryMFAStatusResponse.self, from: response.body)
                #expect(!status.enabled)
                #expect(!status.hasValidCodes)
            }
        }
    }
}
