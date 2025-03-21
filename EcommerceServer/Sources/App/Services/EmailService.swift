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
    
    /// Send a password reset verification code
    func sendPasswordResetEmail(to: String, code: String) async throws
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
        do {
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
            
            logger.info("Attempting to send email to \(email) using SendGrid")
            let client = SendGridClient(httpClient: self.httpClient, apiKey: self.apiKey)
            try await client.send(email: sendGridEmail)
            logger.info("Successfully sent email to \(email)")
        } catch {
            logger.error("Failed to send email to \(email): \(error)")
            throw error
        }
    }
    
    func sendVerificationEmail(to email: String, code: String) async throws {
        let subject = "Verify your email address"
        let htmlContent = """
            <h1>Email Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Sent verification email to \(email)")
    }
    
    func send2FASetupEmail(to email: String, code: String) async throws {
        let subject = "2FA Setup Verification"
        let htmlContent = """
            <h1>2FA Setup Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Sent 2FA setup email to \(email)")
    }
    
    func send2FADisableEmail(to email: String, code: String) async throws {
        let subject = "2FA Disable Verification"
        let htmlContent = """
            <h1>2FA Disable Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Sent 2FA disable email to \(email)")
    }
    
    func send2FALoginEmail(to email: String, code: String) async throws {
        let subject = "Login Verification Code"
        let htmlContent = """
            <h1>Login Verification</h1>
            <p>Your verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 5 minutes.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Sent 2FA login email to \(email)")
    }
    
    func sendPasswordResetEmail(to email: String, code: String) async throws {
        let subject = "Password Reset Request"
        let htmlContent = """
            <h1>Password Reset</h1>
            <p>You have requested to reset your password.</p>
            <p>Your password reset code is: <strong>\(code)</strong></p>
            <p>This code will expire in 30 minutes.</p>
            <p>If you did not request this password reset, please ignore this email or contact support if you have concerns.</p>
            """
        
        try await sendEmail(to: email, subject: subject, htmlContent: htmlContent)
        logger.info("Sent password reset email to \(email)")
    }
}

/// Empty struct for emails without dynamic template data
struct NoTemplateData: Codable, Sendable {}

/// Mock email service for testing
struct MockEmailService: EmailService {
    private let logger: Logger
    
    init(logger: Logger) {
        // Double check we're in testing environment
        guard Environment.current == .testing else {
            fatalError("MockEmailService should only be used in testing environment (current: \(Environment.current))")
        }
        self.logger = logger
    }
    
    func sendVerificationEmail(to email: String, code: String) async throws {
        // In testing environment, we always log the code as 123456
        logger.info("Mock email service: Verification code for \(email) is 123456")
    }
    
    func send2FASetupEmail(to email: String, code: String) async throws {
        // In testing environment, we always log the code as 123456
        logger.info("Mock email service: 2FA setup code for \(email) is 123456")
    }
    
    func send2FADisableEmail(to email: String, code: String) async throws {
        // In testing environment, we always log the code as 123456
        logger.info("Mock email service: 2FA disable code for \(email) is 123456")
    }
    
    func send2FALoginEmail(to email: String, code: String) async throws {
        // In testing environment, we always log the code as 123456
        logger.info("Mock email service: 2FA login code for \(email) is 123456")
    }
    
    func sendPasswordResetEmail(to email: String, code: String) async throws {
        // In testing environment, we always log the code as 123456
        logger.info("Mock email service: Password reset code for \(email) is 123456")
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
