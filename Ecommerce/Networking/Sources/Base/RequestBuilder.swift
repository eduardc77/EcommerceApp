import Foundation

struct RequestBuilder {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private enum ContentType {
        case json
        case formURLEncoded
        
        var value: String {
            switch self {
            case .json:
                return "application/json"
            case .formURLEncoded:
                return "application/x-www-form-urlencoded"
            }
        }
    }

    static func buildRequest(for endpoint: APIEndpoint, in environment: APIEnvironment) throws -> URLRequest {
        let urlComponents = makeURLComponents(from: environment, path: endpoint.path, queryParameters: endpoint.queryItems(for: environment))
        guard let requestURL = urlComponents.url else {
            throw NetworkError.invalidURLComponents(description: "Invalid URL components: \(urlComponents)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = endpoint.httpMethod.method
        request.allHTTPHeaderFields = endpoint.headers(for: environment)
        
        // Add default headers and set the request body
        if let formData = endpoint.encodedFormData {
            setDefaultHeaders(for: &request, contentType: .formURLEncoded)
            request.httpBody = formData
        } else if let body = endpoint.requestBody {
            setDefaultHeaders(for: &request, contentType: .json)
            if let encodable = body as? Encodable {
                request.httpBody = try encoder.encode(encodable)
            } else {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }
        }
        
        return request
    }
    
    static func addAuthorization(to request: URLRequest, token: String) -> URLRequest {
        var authorizedRequest = request
        authorizedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return authorizedRequest
    }
    
    static func buildMultipartRequest(for endpoint: APIEndpoint, in environment: APIEnvironment, multipartFormData: MultipartFormData) throws -> URLRequest {
        let urlComponents = makeURLComponents(from: environment, path: endpoint.path, queryParameters: endpoint.queryItems(for: environment))
        guard let requestURL = urlComponents.url else {
            throw NetworkError.invalidURLComponents(description: "Invalid URL components: \(urlComponents)")
        }
        var request = URLRequest(url: requestURL)
        request.httpMethod = endpoint.httpMethod.method
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        endpoint.headers(for: environment).forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        let body = multipartFormData.createBody(boundary: boundary)
        request.httpBody = body
        
        return request
    }
    
    public static func makeURLComponents(from environment: APIEnvironment, path: String, queryParameters: [URLQueryItem]) -> URLComponents {
        var urlComponents = URLComponents()
        urlComponents.scheme = environment.scheme
        urlComponents.host = environment.host
        urlComponents.port = environment.port
        urlComponents.path = pathComponent(for: environment, path: path)
        if !queryParameters.isEmpty {
            urlComponents.queryItems = queryParameters
        }
        return urlComponents
    }
    
    private static func pathComponent(for environment: APIEnvironment, path: String) -> String {
        var pathComponent = ""
        
        if !environment.domain.isEmpty {
            pathComponent += environment.domain
        }
        if let apiVersion = environment.apiVersion {
            pathComponent += apiVersion
        }
        
        pathComponent += path
        
        return pathComponent
    }
    
    private static func setDefaultHeaders(for request: inout URLRequest, contentType: ContentType) {
        if request.value(forHTTPHeaderField: "Accept") == nil {
            request.setValue(contentType.value, forHTTPHeaderField: "Accept")
        }
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(contentType.value, forHTTPHeaderField: "Content-Type")
        }
    }
}
