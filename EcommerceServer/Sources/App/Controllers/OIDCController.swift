import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import JWTKit

/// Controller for OpenID Connect Discovery endpoints
struct OIDCController {
    typealias Context = AppRequestContext
    private let baseUrl: String
    
    init(baseUrl: String) {
        self.baseUrl = baseUrl
    }
    
    /// Add .well-known OpenID Connect discovery endpoints
    func addRoutes(to group: RouterGroup<Context>) {
        group.get("openid-configuration", use: getOpenIDConfiguration)
    }
    
    /// Get the OpenID Connect discovery document
    /// This endpoint follows the OpenID Connect Discovery 1.0 specification
    @Sendable func getOpenIDConfiguration(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<OIDCConfiguration> {
        // Create OpenID Connect configuration document
        let config = OIDCConfiguration.defaultConfiguration(baseUrl: baseUrl)
        
        return .init(
            status: .ok,
            response: config
        )
    }
} 