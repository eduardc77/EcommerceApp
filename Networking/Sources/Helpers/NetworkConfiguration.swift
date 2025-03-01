import Foundation

public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

public struct NetworkConfiguration {
    public static func configureURLSession(
        timeoutForRequest: TimeInterval = 30.0,
        timeoutForResource: TimeInterval = 60.0,
        cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
        networkServiceType: URLRequest.NetworkServiceType = .default,
        allowsCellularAccess: Bool = true,
        httpAdditionalHeaders: [String: String]? = nil,
        waitsForConnectivity: Bool = true,
        multipathServiceType: URLSessionConfiguration.MultipathServiceType = .none
    ) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutForRequest
        configuration.timeoutIntervalForResource = timeoutForResource
        configuration.requestCachePolicy = cachePolicy
        configuration.networkServiceType = networkServiceType
        configuration.allowsCellularAccess = allowsCellularAccess
        configuration.httpAdditionalHeaders = httpAdditionalHeaders
        configuration.waitsForConnectivity = waitsForConnectivity
        configuration.multipathServiceType = multipathServiceType
        return URLSession(configuration: configuration)
    }

    public static let `default` = configureURLSession()
}
