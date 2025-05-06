import Testing
@testable import Ecommerce
@testable import Networking

@Suite("Auth Manager Tests")
struct AuthManagerTests {
    
    // MARK: - Basic Sign In Tests
    
    @Test("Sign in succeeds with valid credentials")
    func signInSucceeds() async throws {
        // Given
        let manager = await createManager()
        let expectedUser = createTestUser()
        let authResponse = createSuccessAuthResponse(user: expectedUser)
        await manager.mockAuthService.setSignInResult(.success(authResponse))
        
        // When
        await manager.sut.signIn(identifier: "test@example.com", password: "password123")
        
        // Then
        #expect(await manager.sut.isAuthenticated)
        #expect(await manager.sut.currentUser?.id == expectedUser.id)
        #expect(await manager.sut.signInError == nil)
        #expect(await !manager.sut.requiresTOTPVerification)
        #expect(await !manager.sut.requiresEmailMFAVerification)
        
        // Verify service calls
        let signInCalls = await manager.mockAuthService.signInCalls
        #expect(signInCalls.count == 1)
        #expect(signInCalls[0].identifier == "test@example.com")
        #expect(signInCalls[0].password == "password123")
        
        // Verify token storage
        #expect(await manager.mockAuthorizationManager.storeTokenCalled)
    }
    
    @Test("Sign in fails with invalid credentials")
    func signInFailsWithInvalidCredentials() async throws {
        // Given
        let manager = await createManager()
        await manager.mockAuthService.setSignInResult(.failure(
            NetworkError.unauthorized(description: "Invalid credentials")
        ))
        
        // When
        await manager.sut.signIn(identifier: "test@example.com", password: "wrongpass")
        
        // Then - Wait a bit for state to update
        try await Task.sleep(for: .milliseconds(100))
        
        #expect(await !manager.sut.isAuthenticated)
        #expect(await manager.sut.currentUser == nil)
        #expect(await manager.sut.signInError == .invalidCredentials)
        #expect(await !manager.sut.requiresTOTPVerification)
        #expect(await !manager.sut.requiresEmailMFAVerification)
        
        // Verify token was not stored
        #expect(await !manager.mockAuthorizationManager.storeTokenCalled)
    } 
    
    @Test("Sign in with rate limiting returns correct error")
    func signInWithRateLimiting() async throws {
        // Given
        let manager = await createManager()
        await manager.mockAuthService.setSignInResult(.failure(
            NetworkError.clientError(
                statusCode: 429,
                description: "Too many attempts",
                headers: ["Retry-After": "300"],
                data: nil
            )
        ))
        
        // When
        await manager.sut.signIn(identifier: "test@example.com", password: "password123")
        
        // Then
        #expect(await !manager.sut.isAuthenticated)
        #expect(await manager.sut.currentUser == nil)
        if case .accountLocked(let retryAfter) = await manager.sut.signInError {
            #expect(retryAfter == 300)
        } else {
            throw TestError("Expected accountLocked error with retry after")
        }
    }
    
    // MARK: - MFA Tests
    
    @Test("Sign in requiring TOTP verification")
    func signInRequiringTOTP() async throws {
        // Given
        let manager = await createManager()
        let response = AuthResponse(
            stateToken: "test-state-token",
            status: AuthResponse.STATUS_MFA_TOTP_REQUIRED,
            availableMfaMethods: [.totp]
        )
        await manager.mockAuthService.setSignInResult(.success(response))
        
        // When
        await manager.sut.signIn(identifier: "test@example.com", password: "password123")
        
        // Then
        #expect(await !manager.sut.isAuthenticated)
        #expect(await manager.sut.requiresTOTPVerification)
        #expect(await manager.sut.pendingSignInResponse?.stateToken == "test-state-token")
        let methods = await manager.sut.availableMFAMethods
        #expect(methods.count == 1)
        #expect(methods[0] == .totp)
    }
    
    @Test("Complete TOTP verification flow")
    func completeTOTPVerification() async throws {
        // Given
        let manager = await createManager()
        let initialResponse = AuthResponse(
            stateToken: "test-state-token",
            status: AuthResponse.STATUS_MFA_TOTP_REQUIRED,
            availableMfaMethods: [.totp]
        )
        
        let finalUser = createTestUser(mfaEnabled: true)
        let finalResponse = createSuccessAuthResponse(user: finalUser)
        
        // Set up mock responses
        await manager.mockAuthService.setSignInResult(.success(initialResponse))
        
        // When - Initial sign in
        await manager.sut.signIn(identifier: "test@example.com", password: "password123")
        
        // Then - Should require TOTP
        #expect(await !manager.sut.isAuthenticated)
        #expect(await manager.sut.requiresTOTPVerification)
        
        // When - Verify TOTP
        await manager.mockAuthService.setSignInResult(.success(finalResponse))
        try await manager.sut.verifyTOTPSignIn(code: "123456", stateToken: "test-state-token")
        
        // Then - Should be authenticated
        #expect(await manager.sut.isAuthenticated)
        #expect(await !manager.sut.requiresTOTPVerification)
        #expect(await manager.sut.currentUser?.id == finalUser.id)
        
        // Verify TOTP verification call
        let totpCalls = await manager.mockAuthService.verifyTOTPCalls
        #expect(totpCalls.count == 1)
        #expect(totpCalls[0].code == "123456")
        #expect(totpCalls[0].stateToken == "test-state-token")
    }
    
    @Test("Sign in requiring email MFA verification")
    func signInRequiringEmailMFA() async throws {
        // Given
        let manager = await createManager()
        let response = AuthResponse(
            stateToken: "test-state-token",
            status: AuthResponse.STATUS_MFA_EMAIL_REQUIRED,
            maskedEmail: "t***t@example.com",
            availableMfaMethods: [.email]
        )
        await manager.mockAuthService.setSignInResult(.success(response))
        
        // When
        await manager.sut.signIn(identifier: "test@example.com", password: "password123")
        
        // Then
        #expect(await !manager.sut.isAuthenticated)
        #expect(await manager.sut.requiresEmailMFAVerification)
        #expect(await !manager.sut.requiresTOTPVerification)
        #expect(await manager.sut.pendingSignInResponse?.stateToken == "test-state-token")
        let methods = await manager.sut.availableMFAMethods
        #expect(methods.count == 1)
        #expect(methods[0] == .email)
    }
    
    // MARK: - Sign Up Tests
    
    @Test("Sign up succeeds with valid data")
    func signUpSucceeds() async throws {
        // Given
        let manager = await createManager()
        let expectedUser = createTestUser()
        let authResponse = createSuccessAuthResponse(user: expectedUser)
        await manager.mockAuthService.setSignUpResult(.success(authResponse))
        
        // When
        try await manager.sut.signUp(
            username: "testuser",
            email: "test@example.com",
            password: "password123",
            displayName: "Test User"
        )
        
        // Then
        #expect(await manager.sut.isAuthenticated)
        #expect(await manager.sut.currentUser?.id == expectedUser.id)
        #expect(await manager.sut.signUpError == nil)
        
        // Verify service calls
        let signUpCalls = await manager.mockAuthService.signUpCalls
        #expect(signUpCalls.count == 1)
        #expect(signUpCalls[0].username == "testuser")
        #expect(signUpCalls[0].email == "test@example.com")
        
        // Verify token storage
        #expect(await manager.mockAuthorizationManager.storeTokenCalled)
    }
    
    @Test("Sign up requiring email verification")
    func signUpRequiringEmailVerification() async throws {
        // Given
        let manager = await createManager()
        let response = AuthResponse(
            stateToken: "test-state-token",
            status: AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED,
            maskedEmail: "t***t@example.com"
        )
        await manager.mockAuthService.setSignUpResult(.success(response))
        
        // When
        try await manager.sut.signUp(
            username: "testuser",
            email: "test@example.com",
            password: "password123",
            displayName: "Test User"
        )
        
        // Then
        #expect(await !manager.sut.isAuthenticated)
        #expect(await manager.sut.requiresEmailVerification)
        #expect(await manager.sut.pendingSignInResponse?.stateToken == "test-state-token")
        #expect(await manager.sut.pendingCredentials?.identifier == "test@example.com")
        #expect(await manager.sut.pendingCredentials?.password == "password123")
    }
}

// MARK: - Test Helpers
extension AuthManagerTests {
    
    actor TestManager {
        let sut: AuthManager
        let mockAuthService: MockAuthenticationService
        let mockUserService: MockUserService
        let mockAuthorizationManager: MockAuthorizationManager
        let mockTOTPManager: TOTPManager
        let mockEmailVerificationManager: EmailVerificationManager
        let mockRecoveryCodesManager: RecoveryCodesManager
        
        init() async {
            self.mockAuthService = MockAuthenticationService()
            self.mockUserService = MockUserService()
            self.mockAuthorizationManager = MockAuthorizationManager()
            
            let mockTOTPService = MockTOTPService()
            self.mockTOTPManager = await TOTPManager(totpService: mockTOTPService)
            
            let mockEmailVerificationService = MockEmailVerificationService()
            self.mockEmailVerificationManager = await EmailVerificationManager(
                emailVerificationService: mockEmailVerificationService
            )
            
            let mockRecoveryCodesService = MockRecoveryCodesService()
            self.mockRecoveryCodesManager = await RecoveryCodesManager(
                recoveryCodesService: mockRecoveryCodesService
            )
            
            self.sut = await AuthManager(
                authService: mockAuthService,
                userService: mockUserService,
                totpManager: mockTOTPManager,
                emailVerificationManager: mockEmailVerificationManager,
                recoveryCodesManager: mockRecoveryCodesManager,
                authorizationManager: mockAuthorizationManager
            )
        }
    }
    
    func createManager() async -> TestManager {
        await TestManager()
    }
    
    func createTestUser(mfaEnabled: Bool = false) -> UserResponse {
        UserResponse(
            id: "test-id",
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            profilePicture: nil,
            role: .customer,
            emailVerified: true,
            createdAt: "2024-01-01T00:00:00Z",
            updatedAt: "2024-01-01T00:00:00Z",
            mfaEnabled: mfaEnabled,
            lastSignInAt: "2024-01-01T00:00:00Z",
            hasPasswordAuth: true
        )
    }
    
    func createSuccessAuthResponse(user: UserResponse) -> AuthResponse {
        AuthResponse(
            accessToken: "test-access-token",
            refreshToken: "test-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: "2024-01-01T01:00:00Z",
            user: user,
            status: AuthResponse.STATUS_SUCCESS
        )
    }
}
