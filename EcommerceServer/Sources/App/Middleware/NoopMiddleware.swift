import Foundation
import Hummingbird

/// A middleware that does nothing and just passes the request to the next middleware
/// Used as a placeholder when a feature is disabled
struct NoopMiddleware: MiddlewareProtocol {
    func handle(_ request: Request, context: AppRequestContext, next: (Request, AppRequestContext) async throws -> Response) async throws -> Response {
        return try await next(request, context)
    }
} 