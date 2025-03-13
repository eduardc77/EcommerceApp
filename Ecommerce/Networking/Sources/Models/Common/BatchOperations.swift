import Foundation

public struct BatchOperationRequest<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let operation: BatchOperation
    
    public init(items: [T], operation: BatchOperation) {
        self.items = items
        self.operation = operation
    }
}

public enum BatchOperation: String, Codable, Sendable {
    case create
    case update
    case delete
}

public struct BulkImportRequest: Codable, Sendable {
    public let items: [AnyEncodable]
    public let options: BulkImportOptions
    
    public init(items: [AnyEncodable], options: BulkImportOptions) {
        self.items = items
        self.options = options
    }
}

public struct BulkImportOptions: Codable, Sendable {
    public let skipErrors: Bool
    public let updateExisting: Bool
    
    public init(skipErrors: Bool = false, updateExisting: Bool = false) {
        self.skipErrors = skipErrors
        self.updateExisting = updateExisting
    }
}

/// A type-erasing encodable wrapper
public struct AnyEncodable: Encodable, Sendable {
    private let _encode: (Encoder) throws -> Void
    
    public init<T: Encodable>(_ wrapped: T) {
        _encode = wrapped.encode
    }
    
    public func encode(to encoder: Encoder) throws {
        try _encode(encoder)
    }
} 