@testable import App
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import Testing

@Suite("File Tests")
struct MultipartFormTests {
    // Helper function to create test user and get auth token
    private static func createTestUserAndGetToken(
        client: some TestClientProtocol,
        email: String
    ) async throws -> String {
        let requestBody = TestCreateUserRequest(
            username: "testuser",
            displayName: "Test User",
            email: email,
            password: "TestingV@lid143!#",
            profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
        )

        try await client.execute(
            uri: "/api/v1/auth/register",
            method: .post,
            body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
        ) { response in
            #expect(response.status == .created)
        }
        
        try await client.completeEmailVerification(email: requestBody.email)
        
        let authResponse = try await client.execute(
            uri: "/api/v1/auth/login",
            method: .post,
            auth: .basic(username: requestBody.email, password: requestBody.password)
        ) { response in
            #expect(response.status == .created)
            return try JSONDecoder().decode(AuthResponse.self, from: response.body)
        }
        
        return authResponse.accessToken
    }
    
    // Helper function to create multipart form data
    private static func createMultipartFormData(
        boundary: String,
        filename: String,
        contentType: String,
        data: Data
    ) -> Data {
        var formData = Data()
        
        // Add form fields
        [
            ("file[filename]", filename),
            ("file[contentType]", contentType)
        ].forEach { name, value in
            formData.append("--\(boundary)\r\n".data(using: .utf8)!)
            formData.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            formData.append("\(value)\r\n".data(using: .utf8)!)
        }
        
        // Add file data
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"file[data]\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        formData.append(data)
        formData.append("\r\n".data(using: .utf8)!)
        
        formData.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return formData
    }

    @Test("Should upload and download file successfully")
    func testUploadAndDownload() async throws {
        let app = try await buildApplication(TestAppArguments())
        let testData = "Hello, World!".data(using: .utf8)!
        let boundary = "----HBTestFormBoundaryXYZ123"
        
        try await app.test(.router) { client in
            let accessToken = try await Self.createTestUserAndGetToken(
                client: client,
                email: "fileupload@example.com"
            )
            
            let formData = Self.createMultipartFormData(
                boundary: boundary,
                filename: "test.txt",
                contentType: "text/plain",
                data: testData
            )
            
            // Upload file
            let filename = try await client.execute(
                uri: "/api/v1/files",
                method: .post,
                headers: [
                    .contentType: "multipart/form-data; boundary=\(boundary)",
                    .authorization: "Bearer \(accessToken)"
                ],
                body: ByteBuffer(data: formData)
            ) { response in
                #expect(response.status == .created)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(messageResponse.success)
                return messageResponse.message
            }
            
            // Download file
            try await client.execute(
                uri: "/api/v1/files/\(filename)",
                method: .get,
                headers: [
                    .authorization: "Bearer \(accessToken)"
                ]
            ) { response in
                #expect(response.status == .ok)
                let downloadedString = String(buffer: response.body)
                #expect(downloadedString == String(data: testData, encoding: .utf8)!)
            }
        }
    }

    @Test("Should reject unauthorized upload")
    func testUnauthorizedUpload() async throws {
        let app = try await buildApplication(TestAppArguments())
        let testData = "Hello, World!".data(using: .utf8)!
        let boundary = "----HBTestFormBoundaryXYZ123"
        
        try await app.test(.router) { client in
            let formData = Self.createMultipartFormData(
                boundary: boundary,
                filename: "test.jpg",
                contentType: "image/jpeg",
                data: testData
            )
            
            try await client.execute(
                uri: "/api/v1/files",
                method: .post,
                headers: [.contentType: "multipart/form-data; boundary=\(boundary)"],
                body: ByteBuffer(data: formData)
            ) { response in
                #expect(response.status == .unauthorized)
            }
        }
    }

    @Test("Should handle concurrent uploads")
    func testConcurrentUploads() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            let accessToken = try await Self.createTestUserAndGetToken(
                client: client,
                email: "concurrent@example.com"
            )
            
            await withThrowingTaskGroup(of: Void.self) { group in
                for i in 0..<10 {
                    group.addTask {
                        let testData = "Concurrent test \(i)".data(using: .utf8)!
                        let boundary = "----HBTestFormBoundaryXYZ123\(i)"
                        
                        let formData = Self.createMultipartFormData(
                            boundary: boundary,
                            filename: "concurrent-\(i).txt",
                            contentType: "text/plain",
                            data: testData
                        )
                        
                        try await client.execute(
                            uri: "/api/v1/files",
                            method: .post,
                            headers: [
                                .contentType: "multipart/form-data; boundary=\(boundary)",
                                .authorization: "Bearer \(accessToken)"
                            ],
                            body: ByteBuffer(data: formData)
                        ) { response in
                            #expect(response.status == .created)
                            let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                            #expect(messageResponse.success)
                        }
                    }
                }
            }
        }
    }
    
    @Test("Should reject invalid file types")
    func testInvalidFileType() async throws {
        let app = try await buildApplication(TestAppArguments())
        let testData = "Hello, World!".data(using: .utf8)!
        let boundary = "----HBTestFormBoundaryXYZ123"
        
        try await app.test(.router) { client in
            let accessToken = try await Self.createTestUserAndGetToken(
                client: client,
                email: "invalidtype@example.com"
            )
            
            let formData = Self.createMultipartFormData(
                boundary: boundary,
                filename: "test.exe",
                contentType: "application/x-msdownload",
                data: testData
            )
            
            try await client.execute(
                uri: "/api/v1/files",
                method: .post,
                headers: [
                    .contentType: "multipart/form-data; boundary=\(boundary)",
                    .authorization: "Bearer \(accessToken)"
                ],
                body: ByteBuffer(data: formData)
            ) { response in
                #expect(response.status == .unsupportedMediaType)
                let messageResponse = try JSONDecoder().decode(MessageResponse.self, from: response.body)
                #expect(!messageResponse.success)
            }
        }
    }
} 
