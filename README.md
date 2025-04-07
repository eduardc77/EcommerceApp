# EcommerceApp

A full-stack auth application with a Hummingbird Swift server and iOS mobile client, implementing industry-standard security practices.

## Components

### Server Features

#### 🔐 Authentication Methods
- **Traditional Authentication**
  - Username/Email and Password sign-in
  - Secure password validation and hashing
  - Password history tracking
  - Account lockout protection
  - Forced password change policies

- **Social Authentication**
  - Google Sign-In
  - Apple Sign-In
  - Extensible architecture for additional providers

- **Multi-Factor Authentication (MFA)**
  - Time-based One-Time Password (TOTP)
  - Email-based verification codes
  - Recovery codes for backup access
  - Multiple MFA methods support

#### 🎫 Token Management
- JWT-based authentication
- Access and refresh token support
- Token blacklisting
- Token version control
- Concurrent session management
- Secure token rotation

#### 👤 User Management
- Secure user registration
- Email verification
- Profile management
- Role-based access control (Admin, Staff, Seller, Customer)
- Account recovery options

#### 🔒 Security Features
- Industry-standard password policies
- Brute force protection
- Rate limiting
- Session management
- Secure logging
- HTTPS enforcement
- CORS configuration
- XSS protection
- CSRF protection

#### 📧 Email Communications
- Verification emails
- MFA setup notifications
- Password reset flows
- Security notifications
- SendGrid integration

#### 🛠 API Standards
- RESTful API design
- OAuth 2.0 support
- OpenID Connect support
- Comprehensive error handling
- Detailed logging
- API documentation

### iOS Mobile App Features

#### Authentication Flow
- Sign Up/Sign In screens
- Social Authentication integration
- MFA Support
- Password Recovery flow
- Biometric authentication
- Secure token storage using Keychain

#### User Features
- Profile Management
- Session Management
- Push Notifications
- Offline Support
- Dark/Light mode support
- Localization ready

#### Security Features
- End-to-end encryption
- Certificate pinning
- Jailbreak detection
- Secure data persistence
- Automatic session management
- Biometric authentication

## Technical Stack

### Server
- **Framework**: [Hummingbird](https://github.com/hummingbird-project/hummingbird)
- **Database**: PostgreSQL with Fluent ORM
- **Authentication**: JWT, OAuth 2.0, OpenID Connect
- **Email Service**: SendGrid
- **Documentation**: OpenAPI/Swagger

### iOS App
- **UI Framework**: SwiftUI
- **Architecture**: MVVM
- **Networking**: URLSession with async/await
- **Storage**: CoreData, Keychain
- **Dependencies**: Swift Package Manager

## Getting Started

### Prerequisites
- Xcode 15.0+
- Swift 5.9+
- macOS 14.0+
- PostgreSQL 12+
- SendGrid API Key (for email services)
- Google OAuth credentials (for Google Sign-In)
- Apple Sign-In configuration

### Server Setup
1. Navigate to the Server directory
```bash
cd Server
```

2. Install dependencies
```bash
swift package resolve
```

3. Set up environment variables
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Set up the database:
```bash
swift run migrate
```

5. Run the server
```bash
swift run
```

### iOS App Setup
1. Open EcommerceApp.xcodeproj in Xcode
2. Configure signing and capabilities
3. Update API configuration in Config.swift
4. Build and run the app

### Configuration

The server can be configured through environment variables:

```env
# Server Configuration
PORT=8080
HOST=localhost
ENV=development

# Database Configuration
DATABASE_URL=postgresql://localhost:5432/auth_db

# JWT Configuration
JWT_SECRET=your-secret-key
JWT_EXPIRATION=3600

# Email Configuration
SENDGRID_API_KEY=your-sendgrid-key
FROM_EMAIL=noreply@yourdomain.com

# OAuth Configuration
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Apple Sign In Configuration
APPLE_CLIENT_ID=your-apple-client-id
APPLE_TEAM_ID=your-team-id
APPLE_KEY_ID=your-key-id
```

## Development

### Running Tests
Server:
```bash
cd Server && swift test
```

iOS:
```bash
cd iOS && xcodebuild test -scheme EcommerceApp -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

## Security Implementation

### Server Security
- Secure password hashing with bcrypt
- JWT token security
- Rate limiting and brute force protection
- Secure session management
- Input validation and sanitization
- Comprehensive error handling
- Secure logging practices

### iOS Security
- End-to-end encryption for sensitive data
- Secure token storage using Keychain
- Certificate pinning
- Jailbreak detection
- Biometric authentication
- Automatic session management
- Secure data persistence

## Contributing
Please read [CONTRIBUTING.md](Documentation/CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments
- [Hummingbird](https://github.com/hummingbird-project/hummingbird) - Swift HTTP server framework
- [JWT](https://github.com/vapor/jwt) - JWT implementation
- [SendGrid](https://sendgrid.com/) - Email service provider

## Support
For support, please open an issue in the GitHub repository or contact the maintainers.

## Disclaimer
This application is still work in progress and is created for learning purposes to implement industry-standard practices. While it implements security best practices, proper security auditing and testing should be performed before using in a production environment.
