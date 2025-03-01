import Foundation

public protocol APIRequestData: Sendable {
    /// Optional header parameters.
    var headers: [String: String]? { get }
    
    /// Optional query params.
    var queryParams: [String: String]? { get }
}

public extension APIRequestData {
    /// Convert `queryParams` to URL encoded query items.
    var encodedQueryItems: [URLQueryItem]? {
        queryParams?
            .map { URLQueryItem(name: $0.key, value: $0.value) }
            .sorted { $0.name < $1.name }
    }
}
