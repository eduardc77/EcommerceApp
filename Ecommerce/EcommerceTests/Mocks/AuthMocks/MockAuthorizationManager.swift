@testable import Networking

actor MockAuthorizationManager: AuthorizationManagerProtocol {
    private(set) var storeTokenCalled = false
    private(set) var invalidateTokenCalled = false
    private var storedToken: OAuthToken?
    
    func getValidToken() async throws -> OAuthToken {
        guard let token = storedToken else {
            throw NetworkError.missingToken(description: "No token stored")
        }
        return token
    }
    
    func invalidateToken() async throws {
        invalidateTokenCalled = true
        storedToken = nil
    }
    
    func storeToken(_ token: OAuthToken) async {
        storeTokenCalled = true
        storedToken = token
    }
}
