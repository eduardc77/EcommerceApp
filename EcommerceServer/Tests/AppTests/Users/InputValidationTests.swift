@testable import App
import CryptoKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HummingbirdAuthTesting
import JWTKit
import Testing

@Suite("Input Validation Tests")
struct InputValidationTests {
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
                    username: "emailtest\(invalidEmails.firstIndex(of: invalidEmail)!)",
                    displayName: "Email Test User",
                    email: invalidEmail,
                    password: "TestingValid143!@#",
                    profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
                )
                try await client.execute(
                    uri: "/api/v1/auth/sign-up",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
                ) { response in
                    #expect(response.status == .init(code: 422))
                    let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                    #expect(error.error.message.contains("Invalid email format"))
                }
            }
            
            // Test valid email formats
            let validEmails = [
                "test@example.com",
                "user.name@domain.com",
                "user+tag@example.com",
                "test123@subdomain.domain.com",
                "test.email@domain.co.uk"
            ]
            
            for (index, validEmail) in validEmails.enumerated() {
                let validRequest = TestCreateUserRequest(
                    username: "validmail\(index)",
                    displayName: "Valid Email User",
                    email: validEmail,
                    password: "TestingV@lid143!#Z",
                    profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
                )
                try await client.execute(
                    uri: "/api/v1/auth/sign-up",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
                ) { response in
                    #expect(response.status == .created)
                }
                
                // Complete email verification for valid registrations
                try await client.completeEmailVerification(email: validEmail)
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
                    profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
                )
                try await client.execute(
                    uri: "/api/v1/auth/sign-up",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
                ) { response in
                    #expect(response.status == .init(code: 422))
                    let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                    #expect(error.error.message.contains("Invalid username format"))
                }
            }
            
            // Test valid usernames
            let validUsernames = [
                "johndoe123",
                "john_doe_123",
                "j0hnd0e123",
                "johndoe_123",
                "jane_doe_123",
                "testuser123"
            ]
            
            for (_, validUsername) in validUsernames.enumerated() {
                let validRequest = TestCreateUserRequest(
                    username: validUsername,
                    displayName: "Username Test User",
                    email: "\(validUsername)@example.com",
                    password: "TestingV@lid143!#Z",
                    profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
                )
                try await client.execute(
                    uri: "/api/v1/auth/sign-up",
                    method: .post,
                    body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
                ) { response in
                    #expect(response.status == .created)
                }
                
                // Complete email verification for valid registrations
                try await client.completeEmailVerification(email: "\(validUsername)@example.com")
            }
        }
    }
    
    @Test("Password validation rules are enforced")
    func testPasswordValidation() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // Test too short password
            let shortPasswordRequest = TestCreateUserRequest(
                username: "testuser1",
                displayName: "Test User 1",
                email: "test1@example.com",
                password: "Sh0rt!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(shortPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password without uppercase
            let noUppercaseRequest = TestCreateUserRequest(
                username: "testuser2",
                displayName: "Test User 2",
                email: "test2@example.com",
                password: "nouppercase123!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(noUppercaseRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test common password pattern
            let commonPasswordRequest = TestCreateUserRequest(
                username: "testuser3",
                displayName: "Test User 3",
                email: "test3@example.com",
                password: "Password123!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(commonPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password with repeated characters
            let repeatedCharsRequest = TestCreateUserRequest(
                username: "testuser4",
                displayName: "Test User 4",
                email: "test4@example.com",
                password: "TestAAA123!!!@#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(repeatedCharsRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password with sequential characters
            let sequentialRequest = TestCreateUserRequest(
                username: "testuser5",
                displayName: "Test User 5",
                email: "test5@example.com",
                password: "Test12345!@#$%",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(sequentialRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test password containing username
            let usernameInPasswordRequest = TestCreateUserRequest(
                username: "johndoe",
                displayName: "John Doe",
                email: "john@example.com",
                password: "johndoe123!@#ABC",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(usernameInPasswordRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .init(code: 422))
                let error = try JSONDecoder().decode(ErrorResponse.self, from: response.body)
                #expect(error.error.message.contains("Invalid password"))
            }
            
            // Test valid password
            let validRequest = TestCreateUserRequest(
                username: "validuser",
                displayName: "Valid User",
                email: "valid@example.com",
                password: "V3ryStr0ng&Un!que#",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(validRequest, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: response.body)
                #expect(authResponse.status == AuthResponse.STATUS_EMAIL_VERIFICATION_REQUIRED)
            }
            
            // Complete email verification for valid registration
            try await client.completeEmailVerification(email: validRequest.email)
        }
    }
}
