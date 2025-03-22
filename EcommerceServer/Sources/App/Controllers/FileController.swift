import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdFluent
import NIOFoundationCompat
import HTTPTypes

struct FileController {
    typealias Context = AppRequestContext
    let fluent: Fluent
    let fileIO = FileIO()
    
    // Maximum file size (5MB)
    private let maxFileSize = 5 * 1024 * 1024
    
    // Allowed file types
    private let allowedFileTypes = [
        "image/jpeg",
        "image/png",
        "image/gif",
        "application/pdf",
        "text/plain"  // Added for testing
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
        // Add security headers middleware
        group.add(middleware: SecurityHeadersMiddleware())

        // File management endpoints
        group.post("media/upload", use: uploadFile)
            .get("media/download/:filename", use: download)
        
        // Optional: Add more structured endpoints for different use cases
        let mediaGroup = group.group("media")
        mediaGroup.post("profile/upload", use: uploadFile)
            .post("documents/upload", use: uploadFile)
    }
    
    /// Handle file upload - supports both multipart/form-data and raw bytes
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

        // Check if this is a multipart upload or raw bytes
        if let contentType = request.headers[values: .contentType].first,
           contentType.starts(with: "multipart/form-data") {
            return try await handleMultipartUpload(request, context: context)
        } else {
            return try await handleRawUpload(request, context: context)
        }
    }

    /// Handle multipart form data upload
    private func handleMultipartUpload(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
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

        // Get filename and save file
        let filename = fileName(for: request)
        let filePath = "\(uploadDir)/\(filename)"
        
        do {
            try uploadRequest.file.data.write(to: URL(fileURLWithPath: filePath))
            return .init(
                status: .created,
                response: MessageResponse(
                    message: filename,
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

    /// Handle raw bytes upload like in the example
    private func handleRawUpload(
        _ request: Request,
        context: Context
    ) async throws -> EditedResponse<MessageResponse> {
        let filename = fileName(for: request)
        let filePath = "\(uploadDir)/\(filename)"
        
        do {
            try await fileIO.writeFile(
                contents: request.body,
                path: filePath,
                context: context
            )
            
            return .init(
                status: .created,
                response: MessageResponse(
                    message: filename,
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

    /// Downloads a file by filename.
    /// - Parameter request: any request
    /// - Returns: Response of chunked bytes if success
    /// Note that this download has no login checks and allows anyone to download
    /// by its filename alone.
    @Sendable private func download(_ request: Request, context: Context) async throws -> Response {
        let filename = try context.parameters.require("filename", as: String.self)
        let filePath = "\(uploadDir)/\(filename)"
        let body = try await fileIO.loadFile(
            path: filePath,
            context: context
        )
        return Response(
            status: .ok,
            headers: self.headers(for: filename),
            body: body
        )
    }

    /// Adds headers for a given filename
    private func headers(for filename: String) -> HTTPFields {
        return [
            .contentDisposition: "attachment;filename=\"\(filename)\"",
        ]
    }
}

// MARK: - File Naming

extension FileController {
    private func uuidFileName(_ ext: String = "") -> String {
        return UUID().uuidString.appending(ext)
    }

    private func fileName(for request: Request) -> String {
        guard let fileName = request.headers[.fileName] else {
            return self.uuidFileName()
        }
        return fileName
    }
}

extension HTTPField.Name {
    static var fileName: Self { .init("File-Name")! }
} 
