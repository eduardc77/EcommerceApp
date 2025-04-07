# Setup Guide

This guide provides detailed instructions for setting up both the server and iOS app components of the EcommerceApp.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Server Setup](#server-setup)
- [iOS App Setup](#ios-app-setup)
- [Development Environment](#development-environment)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Required Software
- Xcode 15.0 or later
- macOS 14.0 or later
- PostgreSQL 12 or later
- Swift 5.9 or later
- Git

### Required Accounts & Keys
1. **SendGrid Account**
   - Sign up at [SendGrid](https://sendgrid.com)
   - Create an API key with email sending permissions
   - Verify your sender domain

2. **Google OAuth Credentials**
   - Go to [Google Cloud Console](https://console.cloud.google.com)
   - Create a new project
   - Enable Google Sign-In API
   - Create OAuth 2.0 credentials
   - Add authorized redirect URIs

3. **Apple Developer Account**
   - Enroll in the Apple Developer Program
   - Create an App ID
   - Enable Sign in with Apple capability
   - Generate required certificates

## Server Setup

### 1. Database Setup
```bash
# Install PostgreSQL (if not already installed)
brew install postgresql@14

# Start PostgreSQL service
brew services start postgresql@14

# Create database
createdb auth_db

# Verify database connection
psql -d auth_db -c "\l"
```

### 2. Environment Configuration
```bash
# Navigate to server directory
cd Server

# Copy example environment file
cp .env.example .env

# Open .env in your editor
vim .env
```

Required environment variables:
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

### 3. Server Dependencies
```bash
# Install Swift dependencies
swift package resolve

# Verify dependencies
swift package show-dependencies
```

### 4. Database Migration
```bash
# Run database migrations
swift run migrate

# Verify migrations
swift run migrate --list
```

### 5. Running the Server
```bash
# Run in development mode
swift run

# Run with release configuration
swift run -c release
```

## iOS App Setup

### 1. Xcode Configuration
1. Open EcommerceApp.xcodeproj in Xcode
2. Select your development team
3. Update bundle identifier if needed
4. Enable required capabilities:
   - Sign in with Apple
   - Push Notifications
   - Keychain Sharing

### 2. API Configuration
1. Create `Config.swift` from template:
```bash
cp iOS/Sources/Common/Config.example.swift iOS/Sources/Common/Config.swift
```

2. Update configuration values:
```swift
struct Config {
    static let apiBaseURL = "http://localhost:8080"
    static let googleClientId = "your-google-client-id"
    // Add other configuration values
}
```

### 3. Dependencies
```bash
# Install iOS dependencies
cd iOS
swift package resolve
```

### 4. Running the App
1. Select your target device/simulator
2. Build and run (⌘R)
3. Verify the app launches successfully

## Development Environment

### Recommended Tools
- [Proxyman](https://proxyman.io) - HTTP debugging proxy
- [SwiftLint](https://github.com/realm/SwiftLint) - Swift style enforcement

### Code Style
```bash
# Install SwiftLint
brew install swiftlint

# Run SwiftLint
swiftlint
```

### Git Hooks
```bash
# Install pre-commit hooks
cp scripts/pre-commit .git/hooks/
chmod +x .git/hooks/pre-commit
```

## Troubleshooting

### Common Issues

#### Server Issues
1. **Database Connection Failed**
   - Verify PostgreSQL is running
   - Check database credentials
   - Ensure database exists

2. **Migration Errors**
   - Clear database and retry migrations
   - Check migration files for errors
   - Verify database schema

3. **SendGrid Configuration**
   - Verify API key permissions
   - Check sender email verification
   - Review SendGrid logs

#### iOS Issues
1. **Build Errors**
   - Clean build folder (⇧⌘K)
   - Clear derived data
   - Re-resolve SPM dependencies

2. **Signing Issues**
   - Update provisioning profiles
   - Verify team selection
   - Check bundle identifier

3. **Network Errors**
   - Verify server is running
   - Check API configuration
   - Review ATS settings

### Updating Dependencies
```bash
# Update server dependencies
cd Server
swift package update

# Update iOS dependencies
cd iOS
swift package update
``` 