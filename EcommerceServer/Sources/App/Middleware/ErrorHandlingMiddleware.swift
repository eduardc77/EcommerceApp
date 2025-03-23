import Foundation
import Hummingbird

/// Middleware to handle errors and format them consistently
struct ErrorHandlingMiddleware: MiddlewareProtocol {
    func handle(_ request: Request, context: AppRequestContext, next: (Request, AppRequestContext) async throws -> Response) async throws -> Response {
        do {
            return try await next(request, context)
        } catch let error as HTTPError {
            // Format HTTPError into ErrorResponse
            let response = EditedResponse(
                status: error.status,
                headers: error.headers,  // Preserve headers from the original error
                response: ErrorResponse(
                    error: .init(message: error.body ?? "An error occurred")
                )
            )
            return try await response.response(from: request, context: context)
        } catch {
            // Handle other errors
            context.logger.error("Unhandled error: \(error)")
            let response = EditedResponse(
                status: .internalServerError,
                response: ErrorResponse(
                    error: .init(message: "An internal server error occurred")
                )
            )
            return try await response.response(from: request, context: context)
        }
    }
} 