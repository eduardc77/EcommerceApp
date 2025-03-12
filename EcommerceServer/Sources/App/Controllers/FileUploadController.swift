import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import NIOFoundationCompat

struct FileUploadController {
    typealias Context = AppRequestContext
    let fluent: Fluent
    
    // Maximum file size (5MB)
    private let maxFileSize = 5 * 1024 * 1024
    
    // Allowed file types
    private let allowedFileTypes = [
        "image/jpeg",
        "image/png",
        "image/gif",
        "application/pdf"
    ]
    
    // Upload directory path
    private let uploadDir: String
    
    init(fluent: Fluent) {
        self.fluent = fluent
        // Use FileManager to get a temporary directory path
        self.uploadDir = NSTemporaryDirectory().appending("uploads")
    }
    
    /// Add protected routes that require authentication
    func addProtectedRoutes(to group: RouterGroup<Context>) {
        group.post("upload", use: uploadFile)
    }
    
    /// Handle file upload
    @Sendable func uploadFile(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        // Ensure user is authenticated
        guard context.identity != nil else {
            return .init(
                status: .unauthorized,
                response: MessageResponse(
                    message: "Authentication required",
                    success: false
                )
            )
        }
        
        // Check content type
        guard let contentType = request.headers[values: .contentType].first,
              contentType.starts(with: "multipart/form-data") else {
            return .init(
                status: .unsupportedMediaType,
                response: MessageResponse(
                    message: "Content type must be multipart/form-data",
                    success: false
                )
            )
        }
        
        // Check content length before decoding
        if let contentLength = request.headers[values: .contentLength].first.flatMap(Int.init),
           contentLength > maxFileSize {
            return .init(
                status: .badRequest,
                response: MessageResponse(
                    message: "File size exceeds maximum allowed size of 5MB",
                    success: false
                )
            )
        }
        
        // Decode the multipart request
        let uploadRequest: FileUploadRequest
        do {
            uploadRequest = try await context.multipartDecoder.decode(FileUploadRequest.self, from: request, context: context)
        } catch {
            return .init(
                status: .badRequest,
                response: MessageResponse(
                    message: "Required file field is missing or invalid multipart form data",
                    success: false
                )
            )
        }
        
        // Check file content type
        guard allowedFileTypes.contains(uploadRequest.file.contentType) else {
            return .init(
                status: .unsupportedMediaType,
                response: MessageResponse(
                    message: "File type \(uploadRequest.file.contentType) is not supported. Allowed types: JPEG, PNG, GIF, PDF",
                    success: false
                )
            )
        }
        
        // Check file size after decoding
        guard uploadRequest.file.data.count <= maxFileSize else {
            return .init(
                status: .badRequest,
                response: MessageResponse(
                    message: "File size exceeds maximum allowed size of 5MB",
                    success: false
                )
            )
        }
        
        // Create uploads directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(
                atPath: uploadDir,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            context.logger.error("Failed to create upload directory: \(error)")
            return .init(
                status: .internalServerError,
                response: MessageResponse(
                    message: "Failed to process file upload",
                    success: false
                )
            )
        }
        
        // Generate unique filename
        let fileExtension = uploadRequest.file.filename.split(separator: ".").last.map { ".\($0)" } ?? ""
        let filename = "\(UUID().uuidString)\(fileExtension)"
        let filePath = "\(uploadDir)/\(filename)"
        
        // Save the file
        do {
            try uploadRequest.file.data.write(to: URL(fileURLWithPath: filePath))
        
            return .init(
                status: .created,
                response: MessageResponse(
                    message: "File uploaded successfully",
                    success: true
                )
            )
        } catch {
            context.logger.error("Failed to save file: \(error)")
            return .init(
                status: .internalServerError,
                response: MessageResponse(
                    message: "Failed to save uploaded file",
                    success: false
                )
            )
        }
    }
} 
