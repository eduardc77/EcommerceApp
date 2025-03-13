import Foundation

public enum NetworkError: Error, Sendable {
    case invalidResponse(description: String)
    case unauthorized(description: String)
    case forbidden(description: String)
    case notFound(description: String)
    case clientError(statusCode: Int, description: String)
    case internalServerError(description: String)
    case serviceUnavailable(description: String)
    case badGateway(description: String)
    case gatewayTimeout(description: String)
    case badRequest(description: String)
    case decodingError(description: String)
    case unknownError(statusCode: Int, description: String)
    case timeout(description: String)
    case networkConnectionLost(description: String)
    case dnsLookupFailed(description: String)
    case cannotFindHost(description: String)
    case cannotConnectToHost(description: String)
    case custom(description: String)
    case missingToken(description: String)
    case encodingError(description: String)
    case invalidURLComponents(description: String)
    case invalidRequestBody(description: String)
    
    public var localizedDescription: String {
        switch self {
        case .invalidResponse(let description),
                .unauthorized(let description),
                .forbidden(let description),
                .notFound(let description),
                .badRequest(let description),
                .decodingError(let description),
                .timeout(let description),
                .networkConnectionLost(let description),
                .dnsLookupFailed(let description),
                .cannotFindHost(let description),
                .cannotConnectToHost(let description),
                .custom(let description),
                .missingToken(let description),
                .encodingError(let description),
                .invalidURLComponents(let description),
                .invalidRequestBody(let description),
                .internalServerError(let description),
                .serviceUnavailable(let description),
                .badGateway(let description),
                .gatewayTimeout(let description):
            return description
        case .clientError(let statusCode, let description),
                .unknownError(let statusCode, let description):
            return "Status Code: \(statusCode), Description: \(description)"
        }
    }
}

extension NetworkError: Equatable {}
