@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("Users Tests")
struct UsersTests {
    @Test("Basic app route works")
    func testApp() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            try await client.execute(uri: "/", method: .get) { response in
                #expect(response.status == .ok)
                #expect(String(buffer: response.body) == "Hello")
            }
        }
    }
    
    @Test("Can create a new user")
    func testCreateUser() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            let requestBody = TestCreateUserRequest(
                username: "testuser",
                displayName: "Test User",
                email: "testuser@example.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let userResponse = try JSONDecoder().decode(UserResponse.self, from: response.body)
                #expect(userResponse.username == "testuser")
            }
        }
    }
} 