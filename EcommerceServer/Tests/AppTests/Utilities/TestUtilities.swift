@testable import App
import Foundation
import Hummingbird
import HummingbirdOTP
import HummingbirdTesting
import Testing
import HTTPTypes
import Logging
import JWTKit
import Crypto
import HummingbirdAuth
import HummingbirdFluent
import HummingbirdBcrypt
import CryptoKit

struct TestAppArguments: AppArguments {
    let inMemoryDatabase: Bool = true
    let migrate: Bool = true
    let hostname: String = "127.0.0.1"
    let port = 8080
    let db: String = "sqlite"

    init() {
        // Set test environment variables
        setenv("APP_ENV", "testing", 1)  // Must be "testing" for verification codes to work
        setenv("MIN_PASSWORD_LENGTH", "12", 1)
        setenv("JWT_SECRET", "test-secret-key-for-testing-purposes-only", 1)
        setenv("JWT_ISSUER", "test.api", 1)
        setenv("JWT_AUDIENCE", "test.client", 1)
        setenv("DATABASE_URL", "sqlite://memory", 1)
        setenv("SENDGRID_API_KEY", "", 1)  // Empty API key to force mock service
        setenv("SENDGRID_FROM_EMAIL", "test@example.com", 1)
        setenv("SENDGRID_FROM_NAME", "Test Server", 1)
    }
}

// MARK: - Test Email Verification Extensions
extension TestClientProtocol {
    /// Helper function to complete email verification for a user in tests
    /// - Parameters:
    ///   - email: The email address of the user
    /// - Throws: If verification request fails
    func completeEmailVerification(email: String) async throws {
        // Request new verification code
        try await self.execute(
            uri: "/api/auth/email/resend-verification",
            method: .post,
            body: JSONEncoder().encodeAsByteBuffer(ResendVerificationRequest(email: email), allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .ok else {
                let error = try? JSONDecoder().decode(ErrorResponse.self, from: response.body)
                print("Failed to request verification code: \(error?.error.message ?? "Unknown error")")
                throw HTTPError(.unauthorized, message: error?.error.message ?? "Failed to request verification code")
            }
        }
        
        // Verify email with the test code
        try await self.execute(
            uri: "/api/auth/email/verify-email",
            method: .post,
            body: JSONEncoder().encodeAsByteBuffer(EmailVerifyRequest(code: "123456"), allocator: ByteBufferAllocator())
        ) { response in
            guard response.status == .ok else {
                let error = try? JSONDecoder().decode(ErrorResponse.self, from: response.body)
                print("Failed to verify email: \(error?.error.message ?? "Unknown error")")
                throw HTTPError(.unauthorized, message: error?.error.message ?? "Failed to verify email")
            }
        }
    }
}

// MARK: - Test TOTP Extensions
extension TOTP {
    /// Generate a TOTP code for testing purposes
    /// - Parameter secret: The secret key
    /// - Returns: The generated TOTP code
    /// - Throws: If code generation fails
    static func generateTestCode(from secret: String) throws -> String {
        // For testing, we generate a deterministic 6-digit code based on the secret
        // We use the first character of the secret to determine the base code
        let firstChar = secret.first ?? "A"
        let asciiValue = Int(firstChar.asciiValue ?? 65)  // Default to 'A' if conversion fails
        let baseCode = (asciiValue % 10) * 111111  // Will generate codes like 111111, 222222, 333333, etc.
        return String(format: "%06d", baseCode)
    }
}

// MARK: - Test JWT Extensions
extension JWTKeyCollection {
    /// Generate a test JWT token with the given payload
    /// - Parameters:
    ///   - subject: The subject (user ID) for the token
    ///   - expiration: The expiration date
    ///   - type: The token type (access or refresh)
    ///   - tokenVersion: The token version
    ///   - customSecret: Optional custom secret key for signing (for testing invalid signatures)
    ///   - customIssuer: Optional custom issuer (for testing invalid claims)
    /// - Returns: The signed JWT token
    /// - Throws: If token generation fails
    static func generateTestToken(
        subject: String,
        expiration: Date,
        type: String = "access",
        tokenVersion: Int = 0,
        customSecret: String? = nil,
        customIssuer: String? = nil
    ) async throws -> String {
        let jwtConfig = JWTConfiguration.load()
        let jwtID = UUID().uuidString
        let issuedAt = Date()
        
        let payload = JWTPayloadData(
            subject: .init(value: subject),
            expiration: .init(value: expiration),
            type: type,
            issuer: customIssuer ?? jwtConfig.issuer,
            audience: jwtConfig.audience,
            issuedAt: issuedAt,
            id: jwtID,
            role: Role.customer.rawValue,
            tokenVersion: tokenVersion
        )
        
        let signers = JWTKeyCollection()
        let jwtSecret = customSecret ?? AppConfig.jwtSecret
        guard let secretData = jwtSecret.data(using: .utf8) else {
            throw HTTPError(.internalServerError, message: "JWT secret must be valid UTF-8")
        }
        
        await signers.add(
            hmac: HMACKey(key: SymmetricKey(data: secretData)),
            digestAlgorithm: .sha256,
            kid: "hb_local"
        )
        
        return try await signers.sign(payload, kid: "hb_local")
    }
} 
