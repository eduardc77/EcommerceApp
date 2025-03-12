import Foundation
import ExtrasBase64
import Hummingbird
import MultipartKit
import NIOFoundationCompat

/// Decoder for multipart form data
struct MultipartRequestDecoder: RequestDecoder {
    func decode<T>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T where T: Decodable {
        let decoder = FormDataDecoder()
        return try await decoder.decode(type, from: request, context: context)
    }
}

/// Encoder for multipart form data responses
struct MultipartResponseEncoder: ResponseEncoder {
    func encode<T: Encodable>(_ value: T, from request: Request, context: some RequestContext) throws -> Response {
        let encoder = FormDataEncoder()
        let boundary = "----HBFormBoundary" + String(base32Encoding: (0..<4).map { _ in UInt8.random(in: 0...255) })
        var buffer = ByteBuffer()
        try encoder.encode(value, boundary: boundary, into: &buffer)
        return Response(
            status: .ok,
            headers: [.contentType: "multipart/form-data; boundary=\(boundary)"],
            body: .init(byteBuffer: buffer)
        )
    }
}

extension FormDataDecoder {
    func decode<T: Decodable>(_ type: T.Type, from request: Request, context: some RequestContext) async throws -> T {
        guard let contentType = request.headers[.contentType],
              let mediaType = MediaType(from: contentType),
              let parameter = mediaType.parameter,
              parameter.name == "boundary"
        else {
            throw HTTPError(.unsupportedMediaType)
        }
        let buffer = try await request.body.collect(upTo: context.maxUploadSize)
        return try self.decode(T.self, from: buffer, boundary: parameter.value)
    }
}

/// File upload request structure
struct FileUploadRequest: Codable {
    let file: File
    let metadata: String?
    
    struct File: Codable {
        let filename: String
        let data: Data
        let contentType: String
    }
}

/// Media type parser
struct MediaType {
    let type: String
    let parameter: Parameter?
    
    struct Parameter {
        let name: String
        let value: String
    }
    
    init?(from string: String) {
        let parts = string.split(separator: ";").map(String.init)
        guard !parts.isEmpty else { return nil }
        
        self.type = parts[0].trimmingCharacters(in: .whitespaces)
        
        if parts.count > 1 {
            let paramParts = parts[1].split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
            if paramParts.count == 2 {
                self.parameter = Parameter(name: paramParts[0], value: paramParts[1])
            } else {
                self.parameter = nil
            }
        } else {
            self.parameter = nil
        }
    }
} 
