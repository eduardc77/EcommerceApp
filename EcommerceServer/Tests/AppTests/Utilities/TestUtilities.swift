@testable import App
import Foundation
import Hummingbird

struct TestAppArguments: AppArguments {
    let inMemoryDatabase: Bool = true
    let migrate: Bool = true
    let hostname: String = "127.0.0.1"
    let port = 8080

    init() {
        // Set environment variables for testing
        setenv("APP_ENV", "testing", 1)  // Set explicit test environment
        setenv("MIN_PASSWORD_LENGTH", "12", 1)  // Force minimum 12 characters
        setenv("JWT_SECRET", "test-secret-key-for-testing-purposes-only", 1)
        setenv("JWT_ISSUER", "test.api", 1)
        setenv("JWT_AUDIENCE", "test.client", 1)
    }
}

extension Application {
    static func testable() async throws -> any ApplicationProtocol {
        let app = try await buildApplication(TestAppArguments())
        // Migration is already handled in buildApplication
        return app
    }
} 
