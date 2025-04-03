import Foundation

public struct URLResponse: Codable, Sendable {
    public let url: URL
    
    enum CodingKeys: String, CodingKey {
        case url
    }
    
    public init(url: URL) {
        self.url = url
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Try to decode as a URL directly
        if let url = try? container.decode(URL.self, forKey: .url) {
            self.url = url
        } else if let urlString = try? container.decode(String.self, forKey: .url) {
            // If decoding as URL fails, try decoding as String and convert
            guard let url = URL(string: urlString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .url,
                    in: container, 
                    debugDescription: "Invalid URL string: \(urlString)"
                )
            }
            self.url = url
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.url,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "URL not found in response"
                )
            )
        }
    }
} 
