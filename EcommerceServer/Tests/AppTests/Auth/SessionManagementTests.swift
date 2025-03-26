@testable import App
import Foundation
import Testing
import Hummingbird
import HummingbirdTesting
import HTTPTypes

@Suite("Session Management Tests")
struct SessionManagementTests {
    
    @Test("User can view active sessions")
    func testViewActiveSessions() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "session_user_1",
                displayName: "Session Test User",
                email: "session1@example.com",
                password: "Secur3P@ssw0rd!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Sign in to create a session
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 4. View active sessions
            try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let sessionList = try JSONDecoder().decode(SessionListResponse.self, from: response.body)
                #expect(sessionList.sessions.count >= 1)
                #expect(sessionList.currentSessionId != nil)
                
                // Check that one of the sessions is marked as current
                let hasCurrentSession = sessionList.sessions.contains { $0.isCurrent }
                #expect(hasCurrentSession)
            }
        }
    }
    
    @Test("User can create multiple sessions from different devices")
    func testMultipleSessions() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "session_user_2",
                displayName: "Multiple Session User",
                email: "session2@example.com",
                password: "Secur3P@ssw0rd!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Sign in with different device names to create multiple sessions
            var accessTokens: [String] = []
            let deviceNames = ["iPhone", "MacBook", "iPad"]
            
            for deviceName in deviceNames {
                let authResponse = try await client.execute(
                    uri: "/api/v1/auth/sign-in",
                    method: .post,
                    headers: [HTTPField.Name("X-Device-Name")!: deviceName],
                    auth: .basic(username: requestBody.email, password: requestBody.password)
                ) { response in
                    #expect(response.status == .ok)
                    return try JSONDecoder().decode(AuthResponse.self, from: response.body)
                }
                
                accessTokens.append(authResponse.accessToken!)
            }
            
            // 4. Check sessions list with the most recent token
            let latestToken = accessTokens.last!
            try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(latestToken)
            ) { response in
                #expect(response.status == .ok)
                let sessionList = try JSONDecoder().decode(SessionListResponse.self, from: response.body)
                #expect(sessionList.sessions.count >= deviceNames.count)
                
                // Verify at least one session for each device name
                for deviceName in deviceNames {
                    let hasDeviceSession = sessionList.sessions.contains { $0.deviceName == deviceName }
                    #expect(hasDeviceSession)
                }
            }
        }
    }
    
    @Test("User can revoke a specific session")
    func testRevokeSession() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "session_user_3",
                displayName: "Session Revoke User",
                email: "session3@example.com",
                password: "Secur3P@ssw0rd!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Create first session
            let _ = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                headers: [HTTPField.Name("X-Device-Name")!: "First Device"],
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // Add a small delay to ensure sessions have different timestamps
            try await Task.sleep(for: .milliseconds(200))
            
            // 4. Create second session
            let secondSession = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                headers: [HTTPField.Name("X-Device-Name")!: "Second Device"],
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 5. Get session list to identify the session IDs
            let sessionList = try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(secondSession.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(SessionListResponse.self, from: response.body)
            }
            
            #expect(sessionList.sessions.count >= 2)
            
            // Find the ID of the first session
            let firstSessionId = sessionList.sessions.first { !$0.isCurrent }?.id
            #expect(firstSessionId != nil)
            
            // 6. Revoke the first session
            try await client.execute(
                uri: "/api/v1/auth/sessions/\(firstSessionId!)",
                method: .delete,
                auth: .bearer(secondSession.accessToken!)
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 8. Verify second session token is still valid
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(secondSession.accessToken!)
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 9. Verify the session is no longer in the list
            try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(secondSession.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let updatedList = try JSONDecoder().decode(SessionListResponse.self, from: response.body)
                #expect(updatedList.sessions.count < sessionList.sessions.count)
                let sessionIds = updatedList.sessions.map { $0.id }
                #expect(!sessionIds.contains(firstSessionId!))
            }
        }
    }
    
    @Test("User can revoke all sessions except current one")
    func testRevokeAllOtherSessions() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "session_user_4",
                displayName: "Session Revoke All User",
                email: "session4@example.com",
                password: "Secur3P@ssw0rd!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Create multiple sessions
            var sessions: [AuthResponse] = []
            let deviceNames = ["iPhone", "MacBook", "iPad", "Desktop"]
            
            for deviceName in deviceNames {
                let session = try await client.execute(
                    uri: "/api/v1/auth/sign-in",
                    method: .post,
                    headers: [HTTPField.Name("X-Device-Name")!: deviceName],
                    auth: .basic(username: requestBody.email, password: requestBody.password)
                ) { response in
                    #expect(response.status == .ok)
                    return try JSONDecoder().decode(AuthResponse.self, from: response.body)
                }
                
                sessions.append(session)
                
                // Add a small delay between creating sessions
                try await Task.sleep(for: .milliseconds(200))
            }
            
            // Use the latest session token for our operations
            let currentSessionToken = sessions.last!.accessToken!
            
            // 4. Verify we have multiple sessions
            try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(currentSessionToken)
            ) { response in
                #expect(response.status == .ok)
                let sessionList = try JSONDecoder().decode(SessionListResponse.self, from: response.body)
                #expect(sessionList.sessions.count >= deviceNames.count)
            }
            
            // 5. Revoke all other sessions
            try await client.execute(
                uri: "/api/v1/auth/sessions/revoke-all",
                method: .post,
                auth: .bearer(currentSessionToken)
            ) { response in
                #expect(response.status == .ok)
            }
            
            // Add a longer delay to allow token blacklisting and token version updates to propagate
            try await Task.sleep(for: .milliseconds(500))

            // 7. Verify all old session tokens are now invalid except the current one
            for (index, session) in sessions.dropLast().enumerated() {
                try await client.execute(
                    uri: "/api/v1/auth/me",
                    method: .get,
                    auth: .bearer(session.accessToken!)
                ) { response in
                    #expect(response.status == .unauthorized, "Session \(index) should be invalid")
                }
            }
        }
    }
    
    @Test("Session is properly invalidated on sign out")
    func testSignOut() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "session_user_5",
                displayName: "Session Signout User",
                email: "session5@example.com",
                password: "Secur3P@ssw0rd!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Sign in to create a session
            let authResponse = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            // 4. Verify token works
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .ok)
            }
            
            // 5. Sign out
            try await client.execute(
                uri: "/api/v1/auth/sign-out",
                method: .post,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .noContent)
            }
            
            // 6. Verify token no longer works
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(authResponse.accessToken!)
            ) { response in
                #expect(response.status == .unauthorized)
            }
            
            // 7. Verify no active sessions
            let newSignIn = try await client.execute(
                uri: "/api/v1/auth/sign-in",
                method: .post,
                auth: .basic(username: requestBody.email, password: requestBody.password)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(AuthResponse.self, from: response.body)
            }
            
            try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(newSignIn.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                let sessionList = try JSONDecoder().decode(SessionListResponse.self, from: response.body)
                
                // Should only have the new session we just created
                #expect(sessionList.sessions.count == 1)
            }
        }
    }
    
    @Test("Max concurrent sessions enforced")
    func testMaxConcurrentSessions() async throws {
        let app = try await buildApplication(TestAppArguments())
        
        try await app.test(.router) { client in
            // 1. Create user
            let requestBody = TestCreateUserRequest(
                username: "session_user_6",
                displayName: "Concurrent Sessions User",
                email: "session6@example.com",
                password: "Secur3P@ssw0rd!",
                profilePicture: "https://api.dicebear.com/7.x/avataaars/png"
            )
            
            try await client.execute(
                uri: "/api/v1/auth/sign-up",
                method: .post,
                body: JSONEncoder().encodeAsByteBuffer(requestBody, allocator: ByteBufferAllocator())
            ) { response in
                #expect(response.status == .created)
            }
            
            // 2. Complete email verification
            try await client.completeEmailVerification(email: requestBody.email)
            
            // 3. Create multiple sessions (more than the system max limit, which should be 5)
            var sessions: [AuthResponse] = []
            let maxSessionsToAttempt = 6
            
            for i in 1...maxSessionsToAttempt {
                let deviceName = "Device \(i)"
                let session = try await client.execute(
                    uri: "/api/v1/auth/sign-in",
                    method: .post,
                    headers: [HTTPField.Name("X-Device-Name")!: deviceName],
                    auth: .basic(username: requestBody.email, password: requestBody.password)
                ) { response in
                    // We expect all logins to succeed, but the oldest session should be removed
                    #expect(response.status == .ok)
                    return try JSONDecoder().decode(AuthResponse.self, from: response.body)
                }
                
                sessions.append(session)
                
                // Increase the delay between session creations to ensure proper ordering
                try await Task.sleep(for: .milliseconds(300))
            }
            
            // 4. Get current sessions
            let sessionList = try await client.execute(
                uri: "/api/v1/auth/sessions",
                method: .get,
                auth: .bearer(sessions.last!.accessToken!)
            ) { response in
                #expect(response.status == .ok)
                return try JSONDecoder().decode(SessionListResponse.self, from: response.body)
            }
            
            // Verify system enforces max session limit (5 is the default max)
            // We created 6 sessions, so there should only be 5 active
            #expect(sessionList.sessions.count == 5)
            
            // Add a delay to ensure token blacklisting has propagated
            try await Task.sleep(for: .milliseconds(300))

            // 6. The newest token should still be valid
            try await client.execute(
                uri: "/api/v1/auth/me",
                method: .get,
                auth: .bearer(sessions.last!.accessToken!)
            ) { response in
                #expect(response.status == .ok)
            }
        }
    }
}
