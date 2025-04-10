import Foundation
import Testing
@testable import Networking

final class AuthenticationServiceTests {
    // MARK: - Test Properties
    let mockAPIClient: MockAPIClient
    let mockAuthManager: MockAuthorizationManager
    var sut: AuthenticationService!
    
    // MARK: - Init
    init() {
        self.mockAPIClient = MockAPIClient()
        self.mockAuthManager = MockAuthorizationManager()
    }
    
    // MARK: - Setup
    func setUp() async {
        sut = AuthenticationService(
            apiClient: mockAPIClient,
            authorizationManager: mockAuthManager,
            environment: .develop
        )
    }
    
    // MARK: - Sign In Tests
    @Test("Sign in with valid credentials stores tokens and returns response")
    func testSignInSuccess() async throws {
        await setUp()
        
        // Given
        let request = SignInRequest(identifier: "test@example.com", password: "password123")
        let expectedResponse = AuthResponse(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.mockUser(),
            status: AuthResponse.STATUS_SUCCESS
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.signIn(request: request))
        
        // When
        let response = try await sut.signIn(request: request)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        #expect(response.accessToken == expectedResponse.accessToken)
        #expect(response.refreshToken == expectedResponse.refreshToken)
        await #expect(mockAuthManager.storedToken?.accessToken == expectedResponse.accessToken)
        await #expect(mockAuthManager.storedToken?.refreshToken == expectedResponse.refreshToken)
    }
    
    @Test("Sign in requiring MFA doesn't store tokens")
    func testSignInRequiringMFA() async throws {
        await setUp()
        
        // Given
        let request = SignInRequest(identifier: "test@example.com", password: "password123")
        let expectedResponse = AuthResponse(
            stateToken: "state-token",
            status: AuthResponse.STATUS_MFA_REQUIRED,
            maskedEmail: "t***t@example.com",
            availableMfaMethods: [.totp, .email]
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.signIn(request: request))
        
        // When
        let response = try await sut.signIn(request: request)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_MFA_REQUIRED)
        #expect(response.stateToken == expectedResponse.stateToken)
        #expect(response.maskedEmail == expectedResponse.maskedEmail)
        await #expect(mockAuthManager.storedToken == nil)
    }
    
    // MARK: - Sign Up Tests
    @Test("Sign up with valid data returns success response")
    func testSignUpSuccess() async throws {
        await setUp()
        
        // Given
        let request = SignUpRequest(
            username: "testuser",
            displayName: "Test User",
            email: "test@example.com",
            password: "password123"
        )
        let expectedResponse = AuthResponse(
            stateToken: "verification-state-token",
            status: AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.signUp(request: request))
        
        // When
        let response = try await sut.signUp(request: request)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
        #expect(response.stateToken == expectedResponse.stateToken)
        await #expect(mockAuthManager.storedToken == nil)
    }
    
    // MARK: - MFA Verification Tests
    @Test("Verify TOTP with valid code stores tokens")
    func testVerifyTOTPSuccess() async throws {
        await setUp()
        
        // Given
        let code = "123456"
        let stateToken = "state-token"
        let expectedResponse = AuthResponse(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.mockUser(),
            status: AuthResponse.STATUS_SUCCESS
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.verifyTOTPSignIn(code: code, stateToken: stateToken))
        
        // When
        let response = try await sut.verifyTOTPSignIn(code: code, stateToken: stateToken)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        await #expect(mockAuthManager.storedToken?.accessToken == expectedResponse.accessToken)
        await #expect(mockAuthManager.storedToken?.refreshToken == expectedResponse.refreshToken)
    }
    
    @Test("Verify email MFA with valid code stores tokens")
    func testVerifyEmailMFASuccess() async throws {
        await setUp()
        
        // Given
        let code = "123456"
        let stateToken = "state-token"
        let expectedResponse = AuthResponse(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.mockUser(),
            status: AuthResponse.STATUS_SUCCESS
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.verifyEmailMFASignIn(code: code, stateToken: stateToken))
        
        // When
        let response = try await sut.verifyEmailMFASignIn(code: code, stateToken: stateToken)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        await #expect(mockAuthManager.storedToken?.accessToken == expectedResponse.accessToken)
        await #expect(mockAuthManager.storedToken?.refreshToken == expectedResponse.refreshToken)
    }
    
    // MARK: - Token Management Tests
    @Test("Refresh token with valid token stores new tokens")
    func testRefreshTokenSuccess() async throws {
        await setUp()
        
        // Given
        let refreshToken = "old-refresh-token"
        let expectedResponse = AuthResponse(
            accessToken: "new-access-token",
            refreshToken: "new-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            status: AuthResponse.STATUS_SUCCESS
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.refreshToken(refreshToken))
        
        // When
        let response = try await sut.refreshToken(refreshToken)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        await #expect(mockAuthManager.storedToken?.accessToken == expectedResponse.accessToken)
        await #expect(mockAuthManager.storedToken?.refreshToken == expectedResponse.refreshToken)
    }
    
    @Test("Sign out invalidates tokens")
    func testSignOutSuccess() async throws {
        await setUp()
        
        // Given
        await mockAPIClient.mockEmptyResponse(for: Store.Authentication.signOut)
        
        // When
        try await sut.signOut()
        
        // Then
        await #expect(mockAuthManager.invalidateCalled == true)
    }
    
    // MARK: - Social Authentication Tests
    @Test("Sign in with Google stores tokens on success")
    func testSignInWithGoogleSuccess() async throws {
        await setUp()
        
        // Given
        let idToken = "google-id-token"
        let accessToken = "google-access-token"
        let expectedResponse = AuthResponse(
            accessToken: "app-access-token",
            refreshToken: "app-refresh-token",
            tokenType: "Bearer",
            expiresIn: 3600,
            expiresAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600)),
            user: UserResponse.mockUser(),
            status: AuthResponse.STATUS_SUCCESS
        )
        await mockAPIClient.mockResponse(expectedResponse, for: Store.Authentication.signInWithGoogle(idToken: idToken, accessToken: accessToken))
        
        // When
        let response = try await sut.signInWithGoogle(idToken: idToken, accessToken: accessToken)
        
        // Then
        #expect(response.status == AuthResponse.STATUS_SUCCESS)
        await #expect(mockAuthManager.storedToken?.accessToken == expectedResponse.accessToken)
        await #expect(mockAuthManager.storedToken?.refreshToken == expectedResponse.refreshToken)
    }
}
