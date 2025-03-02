@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("User Registration Tests")
struct UserRegistrationTests {
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
    
    @Test("Prevents duplicate email registration")
    func testDuplicateEmailRegistration() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let firstUser = TestCreateUserRequest(
                username: "firstuser",
                displayName: "First User",
                email: "duplicate@example.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(firstUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt to create second user with same email
            let secondUser = TestCreateUserRequest(
                username: "seconduser",
                displayName: "Second User",
                email: "duplicate@example.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(secondUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .conflict)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("already exists"))
            }
        }
    }
    
    @Test("Prevents duplicate username registration")
    func testDuplicateUsernameRegistration() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create first user
            let firstUser = TestCreateUserRequest(
                username: "duplicateuser",
                displayName: "First User",
                email: "first@example.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(firstUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Attempt to create second user with same username
            let secondUser = TestCreateUserRequest(
                username: "duplicateuser",
                displayName: "Second User",
                email: "second@example.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(secondUser, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .conflict)
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("already exists"))
            }
        }
    }
    
    @Test("Should validate email format")
    func testEmailValidation() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Test invalid email formats
            let invalidEmails = [
                "not.an.email",
                "@missingusername.com",
                "spaces in@email.com",
                "missing.domain@",
                "multiple@@at.com",
                "invalid<char>@domain.com",
                ".starts.with.dot@email.com",
                "ends.with.dot.@email.com",
                "double..dot@email.com"
            ]
            
            for invalidEmail in invalidEmails {
                let requestBody = TestCreateUserRequest(
                    username: "emailtest",
                    displayName: "Email Test User",
                    email: invalidEmail,
                    password: "TestingValid143!@#",
                    avatar: "https://api.dicebear.com/7.x/avataaars/png"
                )
                try await client.execute(
                    uri: "/api/users/register",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
                ) { response in
                    #expect(response.status == .init(code: 422))
                    let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                    #expect(error.error.message.contains("Invalid email format"))
                }
            }
            
            // Test valid email should work
            let validRequest = TestCreateUserRequest(
                username: "emailtest",
                displayName: "Email Test User",
                email: "valid.email+tag@sub.domain.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
        }
    }
    
    @Test("Should validate username format")
    func testUsernameValidation() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Test invalid username formats
            let invalidUsernames = [
                "sh", // too short
                String(repeating: "a", count: 33), // too long
                "user name", // contains space
                "user@name", // invalid character
                "user#name", // invalid character
                "user.name", // invalid character
                "_username", // starts with underscore
                "username_", // ends with underscore
                "12345", // only numbers
                "admin", // reserved word
                "root", // reserved word
                "system" // reserved word
            ]
            
            for invalidUsername in invalidUsernames {
                let requestBody = TestCreateUserRequest(
                    username: invalidUsername,
                    displayName: "Username Test User",
                    email: "username.test@example.com",
                    password: "TestingValid143!@#",
                    avatar: "https://api.dicebear.com/7.x/avataaars/png"
                )
                try await client.execute(
                    uri: "/api/users/register",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
                ) { response in
                    #expect(response.status == .init(code: 422))
                    let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                    #expect(error.error.message.contains("Invalid username format"))
                }
            }
            
            // Test valid username should work
            let validRequest = TestCreateUserRequest(
                username: "valid123user",
                displayName: "Username Test User",
                email: "username.test@example.com",
                password: "TestingValid143!@#",
                avatar: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/users/register",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
        }
    }
} 
