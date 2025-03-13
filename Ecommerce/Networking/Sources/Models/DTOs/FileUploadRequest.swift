import Foundation

/// File data with content type for upload
public struct FileData: Sendable {
    public let data: Data
    public let contentType: String
    
    public init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}

/// Request for file upload with multipart form data
public struct FileUploadRequest: Sendable {
    public let file: FileData
    
    public init(file: FileData) {
        self.file = file
    }
} 