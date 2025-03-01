import Foundation

public protocol APIEndpoint: APIRequestData {
    /// The HTTP method to use for the endpoint.
    var httpMethod: HTTPMethod { get }
    
    /// The endpoint's `APIEnvironment` relative path.
    var path: String { get }
    
    /// Optional request body data.
    var requestBody: Any? { get }
    
    /// Optional form data, which is sent as request body.
    var formParams: [String: String]? { get }
    
    /// Optional mock file for testing.
    var mockFile: String? { get }
}

public extension APIEndpoint {
    var headers: [String: String]? { nil }
    var requestBody: Any? { nil }
    var formParams: [String: String]? { nil }
    var mockFile: String? { nil }
    var queryParams: [String: String]? { nil }
    
    /// Convert `formParams` to `.utf8` encoded data.
    var encodedFormData: Data? {
        guard let formParams, !formParams.isEmpty else { return nil }
        var params = URLComponents()
        params.queryItems = encodedFormItems
        let paramString = params.query
        return paramString?.data(using: .utf8)
    }
    
    /// Convert `formParams` to form encoded query items.
    var encodedFormItems: [URLQueryItem]? {
        formParams?
            .map { URLQueryItem(name: $0.key, value: $0.value.formEncoded()) }
            .sorted { $0.name < $1.name }
    }
    
    func urlRequest(environment: APIEnvironment) throws -> URLRequest {
        return try RequestBuilder.buildRequest(for: self, in: environment)
    }
    
    func multipartURLRequest(environment: APIEnvironment, multipartFormData: MultipartFormData) throws -> URLRequest {
        return try RequestBuilder.buildMultipartRequest(for: self, in: environment, multipartFormData: multipartFormData)
    }
}

extension APIEndpoint {
    func headers(for env: APIEnvironment) -> [String: String] {
        var result = env.headers ?? [:]
        headers?.forEach {
            result[$0.key] = $0.value
        }
        return result
    }
    
    func queryItems(for env: APIEnvironment) -> [URLQueryItem] {
        let routeData = encodedQueryItems ?? []
        let envData = env.encodedQueryItems ?? []
        return routeData + envData
    }
}

private extension String {
    func formEncoded() -> String? {
        self.urlEncoded()?
            .replacingOccurrences(of: "+", with: "%2B")
    }
    
    func urlEncoded() -> String? {
        self.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?
            .replacingOccurrences(of: "&", with: "%26")
    }
}
