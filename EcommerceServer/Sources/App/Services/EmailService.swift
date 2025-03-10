import AsyncHTTPClient
import Logging
import SendGridKit
import Hummingbird

/// Protocol for email service functionality
protocol EmailService {
    /// Send initial email verification code
    func sendVerificationEmail(to: String, code: String) async throws
    
    /// Send a 2FA setup verification code
    func send2FASetupEmail(to: String, code: String) async throws
    
    /// Send a 2FA disable verification code
    func send2FADisableEmail(to: String, code: String) async throws
    
    /// Send a 2FA login verification code
    func send2FALoginEmail(to: String, code: String) async throws
}

/// SendGrid email service implementation using SendGridKit
struct SendGridEmailService: EmailService {
    private let httpClient: HTTPClient
    private let apiKey: String
    private let fromEmail: String
    private let fromName: String
    private let logger: Logger
    
    init(httpClient: HTTPClient, apiKey: String, fromEmail: String, fromName: String, logger: Logger) {
        self.httpClient = httpClient
        self.apiKey = apiKey
        self.fromEmail = fromEmail
        self.fromName = fromName
        self.logger = logger
    }
    
    func sendEmail(to email: String, subject: String, htmlContent: String) async throws {
        let sendGridEmail = SendGridEmail(
            personalizations: [
                Personalization(to: [EmailAddress(email: email)])
            ],
            from: EmailAddress(email: self.fromEmail, name: self.fromName),
            subject: subject,
            content: [
                EmailContent(type: "text/html", value: htmlContent)
            ]
        )
        
        let client = SendGridClient(httpClient: self.httpClient, apiKey: self.apiKey)
        try await client.send(email: sendGridEmail)
    }
    
    func sendVerificationEmail(to email: String, code: String) async throws {
        let subject = "Verify your email address"
        let htmlContent = """
            <h1>Email Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Would send email verification code \(code) to \(email)")
    }
    
    func send2FASetupEmail(to email: String, code: String) async throws {
        let subject = "2FA Setup Verification"
        let htmlContent = """
            <h1>2FA Setup Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Would send 2FA setup code \(code) to \(email)")
    }
    
    func send2FADisableEmail(to email: String, code: String) async throws {
        let subject = "2FA Disable Verification"
        let htmlContent = """
            <h1>2FA Disable Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Would send 2FA disable code \(code) to \(email)")
    }
    
    func send2FALoginEmail(to email: String, code: String) async throws {
        let subject = "Login Verification Code"
        let htmlContent = """
            <h1>Login Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Would send 2FA login code \(code) to \(email)")
    }
}

/// Empty struct for emails without dynamic template data
struct NoTemplateData: Codable, Sendable {}

/// Mock email service for testing
struct MockEmailService: EmailService {
    private let logger: Logger
    
    init(logger: Logger) {
        self.logger = logger
    }
    
    func sendVerificationEmail(to email: String, code: String) async throws {
        logger.info("Would send verification email to \(email) with code \(code)")
    }
    
    func send2FASetupEmail(to email: String, code: String) async throws {
        logger.info("Would send 2FA setup code \(code) to \(email)")
    }
    
    func send2FADisableEmail(to email: String, code: String) async throws {
        logger.info("Would send 2FA disable code \(code) to \(email)")
    }
    
    func send2FALoginEmail(to email: String, code: String) async throws {
        logger.info("Would send 2FA login code \(code) to \(email)")
    }
}

enum SendGridError: Error {
    case missingAPIKey
    case invalidResponse
    case requestFailed(statusCode: Int, message: String)
}

private struct SendGridEmailRequest: Codable {
    let personalizations: [Personalization]
    let from: EmailAddress
    let subject: String
    let content: [Content]
    
    struct Personalization: Codable {
        let to: [EmailAddress]
    }
    
    struct EmailAddress: Codable {
        let email: String
    }
    
    struct Content: Codable {
        let type: String
        let value: String
    }
} 
