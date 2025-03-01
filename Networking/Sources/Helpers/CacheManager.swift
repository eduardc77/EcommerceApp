import Foundation
import OSLog

public actor CacheManager {
    private let urlCache: URLCache = URLCache.shared

    public init(
        memoryCapacity: Int = 50 * 1024 * 1024,
        diskCapacity: Int = 200 * 1024 * 1024
    ) {
        // Configure shared cache capacity if needed
        URLCache.shared.memoryCapacity = memoryCapacity
        URLCache.shared.diskCapacity = diskCapacity
    }

    // MARK: - Public Methods
    
    public func checkCachedResponse(for request: URLRequest) async -> (Data, HTTPURLResponse)? {
        guard let url = request.url,
              request.httpMethod == HTTPMethod.get.method,
              let cachedResponse = getCachedResponse(for: url),
              let httpResponse = cachedResponse.response as? HTTPURLResponse
        else { return nil }
        
        // Create a new request with validation headers
        var validationRequest = request
        if let etag = httpResponse.allHeaderFields["ETag"] as? String {
            validationRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = httpResponse.allHeaderFields["Last-Modified"] as? String {
            validationRequest.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }
        
        // Always return nil to force a server check
        return nil
    }
    
    public func handleNotModifiedResponse(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url,
              let cachedResponse = getCachedResponse(for: url),
              let cachedHttpResponse = cachedResponse.response as? HTTPURLResponse
        else {
            throw NetworkError.invalidResponse(description: "304 received but no cache found")
        }
        Logger.networking.info("Returning cached response (Not Modified)")
        return (cachedResponse.data, cachedHttpResponse)
    }

    public func cacheResponse(_ data: Data, for url: URL, response: HTTPURLResponse) {
        let cachedResponse = CachedURLResponse(
            response: response,
            data: data,
            storagePolicy: .allowed
        )
        urlCache.storeCachedResponse(cachedResponse, for: URLRequest(url: url))
    }

    public func invalidateCache(for url: URL) {
        urlCache.removeCachedResponse(for: URLRequest(url: url))
    }

    public func invalidateCacheForCategory(_ categoryId: Int?) {
        // Create the base URL for products or category
        let baseURL = categoryId.map { 
            "https://api.escuelajs.co/api/v1/categories/\($0)/products"
        } ?? "https://api.escuelajs.co/api/v1/products"
        
        // Invalidate the base URL
        if let url = URL(string: baseURL) {
            invalidateCache(for: url)
        }
        
        // Also invalidate any paginated URLs for this category
        for offset in stride(from: 0, to: 100, by: 10) {
            let paginatedURL = baseURL + "?offset=\(offset)&limit=11"
            if let url = URL(string: paginatedURL) {
                invalidateCache(for: url)
            }
        }
    }

    public func clearCache() {
        urlCache.removeAllCachedResponses()
    }
    
    // MARK: - Private Methods
    
    private func getCachedResponse(for url: URL) -> CachedURLResponse? {
        let request = URLRequest(url: url)
        return urlCache.cachedResponse(for: request)
    }
}
