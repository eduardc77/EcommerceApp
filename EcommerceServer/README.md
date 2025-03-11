# EcommerceServer

## Environment Setup

The server supports multiple environments: development, testing, staging, and production.

### Local Development

1. Copy the example environment file:
```bash
cp .env.example .env.development
```

2. Edit `.env.development` with your settings:
- Set your SendGrid API key
- Configure your email settings
- Adjust other settings as needed

3. Create a symlink to use development environment:
```bash
ln -sf .env.development .env
```

4. Start the server:
```bash
swift run
```

### Testing

1. Copy the testing environment file:
```bash
cp .env.example .env.testing
```

2. Run tests:
```bash
swift test
```

The testing environment:
- Uses in-memory SQLite database
- Uses mock email service (no real emails sent)
- Has CSRF protection disabled
- Uses fixed verification code "123456"

### Production Deployment

In production, set environment variables directly on your hosting platform:

Required variables:
- `APP_ENV=production`
- `JWT_SECRET` (min 32 chars)
- `SENDGRID_API_KEY`
- `SENDGRID_FROM_EMAIL`
- `SENDGRID_FROM_NAME`
- `ALLOWED_ORIGINS`
- `BASE_URL`

Optional variables (have defaults):
- `SERVER_PORT` (default: 8080)
- `SERVER_HOST` (default: 127.0.0.1)
- `DATABASE_PATH`
- `LOG_LEVEL`
- `RATE_LIMIT_PER_MINUTE`
- `TRUSTED_PROXIES`

### Environment Files

- `.env.example`: Template with dummy values (committed)
- `.env.development`: Local development settings (not committed)
- `.env.testing`: Testing environment settings (not committed)
- `.env.staging`: Staging environment settings (not committed)
- `.env.production`: Production environment settings (not committed)
- `.env`: Symlink to your current environment file (not committed)

Never commit sensitive values to version control! 