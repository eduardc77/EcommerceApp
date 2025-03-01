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
    
    public func decode<T: Decodable>(_ data: Data) async throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            Logger.networking.error("Failed to decode response: \(error)")
            throw NetworkError.decodingError(description: "Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    public func decodeServerError(from data: Data, statusCode: Int, defaultMessage: String? = nil) -> ServerError {
        if let serverError = try? decoder.decode(ServerError.self, from: data) {
            return serverError
        }
        return ServerError(
            error: defaultMessage ?? "Unknown Server Error",
            timestamp: Date(),
            path: "",
            status: statusCode
        )
    }
}
