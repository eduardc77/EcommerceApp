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
        // Log raw response data for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            Logger.networking.debug("Raw response data: \(jsonString)")
        }
        
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
                throw NetworkError.internalServerError(description: errorResponse.error.message)
            }
            throw NetworkError.decodingError(description: "Failed to decode response: \(error.localizedDescription)")
        }
    }
    
    public func decodeError(from data: Data, statusCode: Int) -> NetworkError {
        if let errorResponse = try? decoder.decode(ErrorResponse.self, from: data) {
            let message = errorResponse.error.message
            switch statusCode {
            case 500: return .internalServerError(description: message)
            case 502: return .badGateway(description: message)
            case 503: return .serviceUnavailable(description: message)
            case 504: return .gatewayTimeout(description: message)
            default: return .unknownError(statusCode: statusCode, description: message)
            }
        }
        
        let defaultMessage = HTTPURLResponse.localizedString(forStatusCode: statusCode)
        switch statusCode {
        case 500: return .internalServerError(description: defaultMessage)
        case 502: return .badGateway(description: defaultMessage)
        case 503: return .serviceUnavailable(description: defaultMessage)
        case 504: return .gatewayTimeout(description: defaultMessage)
        default: return .unknownError(statusCode: statusCode, description: defaultMessage)
        }
    }
}
