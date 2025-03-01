import Foundation

public struct MultipartFormData {
    let fields: [String: String] // Regular form fields (key-value pairs)
    let files: [File] // File data
    
    public init(fields: [String: String], files: [File]) {
        self.fields = fields
        self.files = files
    }
    
    // Method for validation
    public func validate() throws {
        if fields.isEmpty && files.isEmpty {
            throw NetworkError.invalidRequestBody(description: "Both fields and files are empty.")
        }
        
        for (key, value) in fields {
            try validateField(key: key, value: value)
        }
        
        for file in files {
            try validateFile(file)
        }
    }
    
    private func validateField(key: String, value: String) throws {
        if key.isEmpty || value.isEmpty {
            throw NetworkError.invalidRequestBody(description: "Field key or value is empty.")
        }
        if !isValidFieldName(key) {
            throw NetworkError.invalidRequestBody(description: "Field key contains invalid characters.")
        }
        if !isValidFieldValue(value) {
            throw NetworkError.invalidRequestBody(description: "Field value contains invalid characters.")
        }
    }
    
    private func validateFile(_ file: File) throws {
        if file.fieldName.isEmpty || file.fileName.isEmpty || file.mimeType.isEmpty || file.fileData.isEmpty {
            throw NetworkError.invalidRequestBody(description: "File field name, file name, mime type, or file data is empty.")
        }
        if !isValidFieldName(file.fieldName) {
            throw NetworkError.invalidRequestBody(description: "File field name contains invalid characters.")
        }
        if !isValidFileName(file.fileName) {
            throw NetworkError.invalidRequestBody(description: "File name contains invalid characters.")
        }
        if !isValidMimeType(file.mimeType) {
            throw NetworkError.invalidRequestBody(description: "Invalid MIME type.")
        }
    }
    
    func createBody(boundary: String) -> Data {
        var body = Data()
        
        // Add form fields
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        
        // Add files
        for file in files {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(file.fieldName)\"; filename=\"\(file.fileName)\"\r\n")
            body.append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.fileData)
            body.append("\r\n")
        }
        
        // End of multipart form data
        body.append("--\(boundary)--\r\n")
        
        return body
    }
    
    // Helper methods for validation
    private func isValidFieldName(_ name: String) -> Bool {
        let invalidCharacters = CharacterSet(charactersIn: " \"'\\")
        return name.rangeOfCharacter(from: invalidCharacters) == nil
    }
    
    private func isValidFieldValue(_ value: String) -> Bool {
        let invalidCharacters = CharacterSet(charactersIn: "\"'\\")
        return value.rangeOfCharacter(from: invalidCharacters) == nil
    }
    
    private func isValidFileName(_ name: String) -> Bool {
        let invalidCharacters = CharacterSet(charactersIn: " \"'\\/:*?<>|")
        return name.rangeOfCharacter(from: invalidCharacters) == nil
    }
    
    private func isValidMimeType(_ mimeType: String) -> Bool {
        let validMimeTypes = ["image/jpeg", "image/png", "application/pdf", "text/plain"]
        return validMimeTypes.contains(mimeType)
    }
}

// Extension for Data to easily append strings
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

public struct File {
    let fieldName: String
    let fileName: String
    let mimeType: String
    let fileData: Data
}
