# Swift Authentication Server API Documentation

## Technical Specifications

### Environment Requirements
- Swift 5.9 or later
- macOS 14 or later
- PostgreSQL 12 or later

### Dependencies
- Hummingbird (v2.0.0+) - Core HTTP server framework
- Hummingbird Auth (v2.0.0+) - Authentication framework
- Hummingbird Fluent (v2.0.0-beta.2+) - ORM integration
- JWT Kit (v5.0.0-beta.4+) - JWT handling
- AsyncHTTPClient (v1.19.0+) - HTTP client
- FluentKit (v1.16.0+) - Database ORM
- SendGrid Kit (v3.0.0+) - Email service integration
- Multipart Kit (v4.0.0+) - File upload handling

## API Endpoints

### Authentication

#### Traditional Authentication

```http
POST /api/v1/auth/sign-up
```
Register a new user account.
```json
{
    "username": "string",
    "display_name": "string",
    "email": "string",
    "password": "string",
    "profile_picture": "string (optional)"
}
```

```http
POST /api/v1/auth/sign-in
```
Sign in with email/username and password.
```json
{
    "email": "string",
    "password": "string"
}
```

#### Social Authentication

```http
POST /api/v1/auth/social/sign-in/google
```
Sign in with Google.
```json
{
    "id_token": "string",
    "access_token": "string (optional)"
}
```

```http
POST /api/v1/auth/social/sign-in/apple
```
Sign in with Apple.
```json
{
    "identity_token": "string",
    "authorization_code": "string",
    "full_name": {
        "givenName": "string (optional)",
        "familyName": "string (optional)"
    },
    "email": "string (optional)"
}
```

#### Token Management

```http
POST /api/v1/auth/refresh
```
Refresh access token.
```json
{
    "refresh_token": "string"
}
```

```http
POST /api/v1/auth/sign-out
```
Sign out and invalidate tokens.

### Multi-Factor Authentication (MFA)

#### TOTP-based MFA

```http
POST /api/v1/mfa/totp/enable
```
Initialize TOTP setup.

```http
POST /api/v1/mfa/totp/verify
```
Verify TOTP setup.
```json
{
    "code": "string"
}
```

```http
POST /api/v1/mfa/totp/disable
```
Disable TOTP.
```json
{
    "password": "string"
}
```

#### Email-based MFA

```http
POST /api/v1/mfa/email/enable
```
Enable email-based MFA.

```http
POST /api/v1/mfa/email/verify
```
Verify email MFA setup.
```json
{
    "code": "string"
}
```

```http
POST /api/v1/mfa/email/disable
```
Disable email MFA.
```json
{
    "password": "string"
}
```

#### Recovery Codes

```http
POST /api/v1/mfa/recovery/generate
```
Generate new recovery codes.

```http
GET /api/v1/mfa/recovery/list
```
List recovery codes status.

```http
POST /api/v1/mfa/recovery/verify
```
Verify recovery code during sign in.
```json
{
    "code": "string",
    "state_token": "string"
}
```

### User Management

```http
GET /api/v1/users/:id
```
Get user details.

```http
PUT /api/v1/users/update-profile
```
Update user profile.
```json
{
    "display_name": "string (optional)",
    "email": "string (optional)",
    "profile_picture": "string (optional)"
}
```

```http
DELETE /api/v1/users/:id
```
Delete user account.

### OAuth 2.0 Endpoints

```http
GET /api/v1/oauth/authorize
```
OAuth 2.0 authorization endpoint.

```http
POST /api/v1/oauth/token
```
OAuth 2.0 token endpoint.

### OpenID Connect Endpoints

```http
GET /.well-known/openid-configuration
```
OpenID Connect discovery document.

## Authentication Flows

### Traditional Sign In Flow
1. User submits credentials
2. Server validates credentials
3. If MFA is enabled:
   - Server returns state token
   - User must complete MFA verification
4. Server issues access and refresh tokens
5. Client stores tokens for future requests

### Social Authentication Flow
1. Client obtains token from social provider
2. Client sends token to server
3. Server verifies token with provider
4. Server creates or updates user account
5. Server issues access and refresh tokens

### MFA Verification Flow
1. User completes primary authentication
2. Server checks if MFA is enabled
3. If enabled:
   - User must provide MFA code
   - Server verifies code
   - On success, issues tokens
4. If disabled:
   - Tokens issued immediately

## Response Formats

### Success Response
```json
{
    "status": "success",
    "data": {
        // Response data
    }
}
```

### Error Response
```json
{
    "status": "error",
    "error": {
        "code": "string",
        "message": "string",
        "details": {} // Optional additional details
    }
}
```

## Security Implementation

### Password Requirements
- Minimum length: 12 characters
- Must contain:
  - Uppercase letters
  - Lowercase letters
  - Numbers
  - Special characters
- Cannot contain:
  - Common patterns
  - Personal information
  - Previously used passwords

### Token Security
- Access tokens expire in 1 hour
- Refresh tokens expire in 30 days
- Tokens are invalidated on:
  - Password change
  - Sign out
  - Security breach detection

### Rate Limiting
- Sign in: 5 attempts per minute
- MFA verification: 3 attempts per code
- Password reset: 3 attempts per hour

### Session Management
- Maximum 5 concurrent sessions
- Sessions can be viewed and revoked
- Automatic session cleanup

## Error Codes

| Code | Description |
|------|-------------|
| 400  | Bad Request |
| 401  | Unauthorized |
| 403  | Forbidden |
| 404  | Not Found |
| 422  | Unprocessable Entity |
| 429  | Too Many Requests |
| 500  | Internal Server Error |

## Best Practices

1. Always use HTTPS in production
2. Implement proper error handling
3. Use refresh tokens for long-term authentication
4. Store tokens securely
5. Implement token rotation
6. Use rate limiting
7. Enable MFA for sensitive operations
8. Monitor for suspicious activity
9. Regular security audits
10. Keep dependencies updated 