public struct EditedResponse<T: Decodable>: Decodable {
    public let status: HTTPStatus
    public let response: T
    
    public init(status: HTTPStatus, response: T) {
        self.status = status
        self.response = response
    }
}

public enum HTTPStatus: Int, Decodable {
    case ok = 200
    case created = 201
    case accepted = 202
    case noContent = 204
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case conflict = 409
    case tooManyRequests = 429
    case internalServerError = 500
    case serviceUnavailable = 503
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let statusCode = try container.decode(Int.self)
        self = HTTPStatus(rawValue: statusCode) ?? .ok
    }
} 