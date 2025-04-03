import Foundation

public struct NetworkConfiguration {
    public static var `default`: URLSession {
        URLSession(
            configuration: configuration(),
            delegate: nil,
            delegateQueue: .main
        )
    }

    public static func configuration(
        timeoutForRequest: TimeInterval = 10,
        timeoutForResource: TimeInterval = 300,
        multipathServiceType: URLSessionConfiguration.MultipathServiceType = .none
    ) -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeoutForRequest
        configuration.timeoutIntervalForResource = timeoutForResource
        configuration.multipathServiceType = multipathServiceType
        configuration.waitsForConnectivity = false
        return configuration
    }

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
}
