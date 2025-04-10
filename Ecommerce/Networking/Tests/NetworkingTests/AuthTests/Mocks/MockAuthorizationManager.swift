@testable import Networking

public final actor MockAuthorizationManager: AuthorizationManagerProtocol {
    private(set) var storedToken: OAuthToken?
    private(set) var invalidateCalled = false
    
    public func storeToken(_ token: OAuthToken) async {
        storedToken = token
    }
    
    public func invalidateToken() async throws {
        invalidateCalled = true
        storedToken = nil
    }
    
    public func getValidToken() async throws -> OAuthToken {
        return storedToken ?? Token.init(accessToken: "", refreshToken: "", expiresIn: 0, expiresAt: "")
    }
}
