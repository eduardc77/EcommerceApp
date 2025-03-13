import Foundation
import OSLog

public actor ResponseHandler {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder? = nil) {
        if let decoder = decoder {
            self.decoder = decoder
        } else {
            let defaultDecoder = JSONDecoder()
            defaultDecoder.keyDecodingStrategy = .convertFromSnakeCase
            defaultDecoder.dateDecodingStrategy = .iso8601
            self.decoder = defaultDecoder
        }
    }
    
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) async throws -> T {
        do {
            // First try to decode as EditedResponse
            if let editedResponse = try? decoder.decode(EditedResponse<T>.self, from: data) {
                return editedResponse.response
            }
            
            // If that fails, try direct decoding
            return try decoder.decode(type, from: data)
        } catch {
            Logger.networking.error("Failed to decode response: \(error)")
            if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
                throw NetworkError.serverError(ServerError(
                    error: errorResponse.error.message,
                    timestamp: Date(),
                    path: "",
                    status: 500
                ))
            }
            throw NetworkError.decodingError(description: "Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    public func decodeServerError(from data: Data, statusCode: Int, defaultMessage: String? = nil) -> ServerError {
        if let serverError = try? decoder.decode(ServerError.self, from: data) {
            return serverError
        }
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            return ServerError(
                error: errorResponse.error.message,
                timestamp: Date(),
                path: "",
                status: statusCode
            )
        }
        return ServerError(
            error: defaultMessage ?? "Unknown Server Error",
            timestamp: Date(),
            path: "",
            status: statusCode
        )
    }
}

/// Server error response format
public struct ErrorResponse: Codable {
    public let error: ErrorDetail
    
    public struct ErrorDetail: Codable {
        public let message: String
    }
}

/// Internal wrapper for server responses
private struct EditedResponse<T: Decodable>: Decodable {
    let status: Int
    let response: T
}
