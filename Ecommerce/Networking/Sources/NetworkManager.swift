import Foundation
import OSLog

/// A manager responsible for handling network requests with caching, authorization, and retry capabilities.
public actor NetworkManager {
    // MARK: - Dependencies
    private let urlSession: URLSessionProtocol
    private let responseHandler: ResponseHandler
    private let cacheManager: CacheManager
    private let authManager: AuthorizationManagerProtocol
    private let retryHandler: RetryHandler
    
    public init(
        authorizationManager: AuthorizationManagerProtocol,
        urlSession: URLSessionProtocol = NetworkConfiguration.default,
        responseHandler: ResponseHandler = ResponseHandler(),
        cacheManager: CacheManager = CacheManager(),
        rateLimiter: RateLimiter = RateLimiter(),
        retryPolicy: RetryPolicy = DefaultRetryPolicy()
    ) {
        self.urlSession = urlSession
        self.responseHandler = responseHandler
        self.cacheManager = cacheManager
        self.authManager = authorizationManager
        self.retryHandler = RetryHandler(retryPolicy: retryPolicy, rateLimiter: rateLimiter)
    }

    public func performRequest(with request: URLRequest, requiresAuthorization: Bool) async throws -> (Data, HTTPURLResponse) {
        try await performRequestWithRetry(
            request: request,
            requiresAuthorization: requiresAuthorization,
            attempt: 0
        )
    }
}

// MARK: - Request Execution
private extension NetworkManager {
    func performRequestWithRetry(
        request: URLRequest, 
        requiresAuthorization: Bool, 
        attempt: Int,
        isRefreshAttempt: Bool = false
    ) async throws -> (Data, HTTPURLResponse) {
        do {
            var requestToSend = request
            if requiresAuthorization {
                let token = try await authManager.getValidToken()
                requestToSend = RequestBuilder.addAuthorization(to: request, token: token.accessToken)
            }
                
            // Add cache control based on HTTP method
            switch request.httpMethod {
            case "GET":
                requestToSend.cachePolicy = .reloadRevalidatingCacheData
                requestToSend.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
            case "POST", "PUT", "DELETE":
                requestToSend.cachePolicy = .reloadIgnoringLocalCacheData
            default:
                break
            }
            
            let (data, response) = try await urlSession.data(for: requestToSend)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse(description: "Invalid response")
            }
            
            return try await handleResponse(request, data: data, response: httpResponse, isRefreshAttempt: isRefreshAttempt)
            
        } catch {
            let shouldRetry = await retryHandler.shouldRetry(error: error, attempt: attempt)
            
            if !isRefreshAttempt && shouldRetry {
                try await retryHandler.handleRetry(attempt: attempt)
                return try await performRequestWithRetry(
                    request: request,
                    requiresAuthorization: requiresAuthorization,
                    attempt: attempt + 1,
                    isRefreshAttempt: isRefreshAttempt
                )
            }
            throw error
        }
    }
    
    func handleResponse(
        _ request: URLRequest,
        data: Data,
        response: URLResponse,
        isRefreshAttempt: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse(description: "Invalid response")
        }
        
        Logger.logResponse(httpResponse, data: data)
        let responseDescription = HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
        
        switch httpResponse.statusCode {
        case 200...299:
            return try await handleSuccessResponse(request, data: data, response: httpResponse)
        case 304:
            return try await cacheManager.handleNotModifiedResponse(for: request)
        case 400...499:
            return try await handleClientError(
                request,
                data: data,
                response: httpResponse,
                description: responseDescription,
                isRefreshAttempt: isRefreshAttempt
            )
        case 500...599:
            return try await handleServerError(data: data, httpResponse: httpResponse, responseDescription: responseDescription)
        default:
            throw NetworkError.unknownError(statusCode: httpResponse.statusCode, description: "Unknown Error: \(responseDescription)")
        }
    }
    
    func handleClientError(
        _ request: URLRequest,
        data: Data,
        response: HTTPURLResponse,
        description: String,
        isRefreshAttempt: Bool
    ) async throws -> (Data, HTTPURLResponse) {
        switch response.statusCode {
        case 400:
            throw NetworkError.badRequest(description: "Bad Request: \(description)")
        case 401, 403:
            if !isRefreshAttempt {
                // Try refresh once
                return try await performRequestWithRetry(
                    request: request,
                    requiresAuthorization: true,
                    attempt: 0,
                    isRefreshAttempt: true
                )
            }
            throw NetworkError.unauthorized(description: "Session expired. Please log in again.")
        case 404:
            throw NetworkError.notFound(description: "Not Found: \(description)")
        case 408:
            throw NetworkError.timeout(description: "Request Timeout: \(description)")
        case 429:
            throw NetworkError.clientError(
                statusCode: response.statusCode,
                description: "Too Many Requests: \(description)",
                headers: response.allHeaderFields as? [String: String] ?? [:]
            )
        default:
            throw NetworkError.clientError(statusCode: response.statusCode, description: "Client Error: \(description)")
        }
    }
}

// MARK: - Response Handling
private extension NetworkManager {
    func handleSuccessResponse(_ request: URLRequest, data: Data, response: HTTPURLResponse) async throws -> (Data, HTTPURLResponse) {
        if request.httpMethod == HTTPMethod.get.method, let url = request.url {
            await cacheManager.cacheResponse(data, for: url, response: response)
        }
        return (data, response)
    }
    
    func handleServerError(data: Data, httpResponse: HTTPURLResponse, responseDescription: String) async throws -> (Data, HTTPURLResponse) {
        throw await responseHandler.decodeError(from: data, statusCode: httpResponse.statusCode)
    }
}

// MARK: - Error Handling
private extension NetworkManager {
    enum ErrorType {
        case badGateway
        case serviceUnavailable
        case gatewayTimeout
        case internalServerError
        case unknown
        
        init(statusCode: Int) {
            switch statusCode {
            case 500: self = .internalServerError
            case 502: self = .badGateway
            case 503: self = .serviceUnavailable
            case 504: self = .gatewayTimeout
            default: self = .unknown
            }
        }
    }
}
