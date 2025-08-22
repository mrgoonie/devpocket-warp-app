# DevPocket API Documentation

## Overview

The DevPocket API is a RESTful API that powers the AI-powered mobile terminal application. It provides endpoints for user authentication, SSH profile management, terminal sessions, subscription management, and system health monitoring.

## API Information

- **Base URL**: 
  - Local Development: `http://localhost:3000`
  - Development: `https://api.dev.devpocket.app`
  - Production: `https://api.devpocket.app`
- **API Version**: v1
- **API Prefix**: `/api/v1`
- **Documentation**: Available at `/docs` (Swagger UI)
- **Authentication**: JWT Bearer tokens

## Quick Start

### 1. Authentication

All protected endpoints require a Bearer token in the Authorization header:

```bash
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     https://api.dev.devpocket.app/api/v1/auth/me
```

### 2. Register a New User

```bash
curl -X POST https://api.dev.devpocket.app/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "testuser",
    "password": "securepassword"
  }'
```

### 3. Login

```bash
curl -X POST https://api.dev.devpocket.app/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "securepassword"
  }'
```

## Core Endpoints

### Health & Monitoring

| Endpoint | Method | Description | Auth Required |
|----------|---------|-------------|---------------|
| `/health` | GET | Comprehensive health check | No |
| `/health/ready` | GET | Kubernetes readiness probe | No |
| `/health/live` | GET | Kubernetes liveness probe | No |
| `/ping` | GET | Simple health check for load balancers | No |

#### Health Check Response Format

The health service returns standardized responses:

**Healthy Response (`200 OK`):**
```json
{
  "status": "ok",
  "timestamp": "2024-01-15T10:30:00Z",
  "uptime": 3600,
  "checks": {
    "database": { "status": "ok", "responseTime": 45, "message": "Database connection successful" },
    "redis": { "status": "ok", "responseTime": 12, "message": "Redis connection successful" },
    "memory": { "status": "ok", "message": "Memory usage is normal" },
    "disk": { "status": "ok", "message": "Disk access successful" }
  }
}
```

**Unhealthy Response (`503 Service Unavailable`):**
```json
{
  "status": "unhealthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "error": "One or more health checks failed"
}
```

### Authentication Endpoints

| Endpoint | Method | Description |
|----------|---------|-------------|
| `/api/v1/auth/register` | POST | Register new user |
| `/api/v1/auth/login` | POST | User login |
| `/api/v1/auth/logout` | POST | User logout |
| `/api/v1/auth/refresh` | POST | Refresh access token |
| `/api/v1/auth/me` | GET | Get current user profile |
| `/api/v1/auth/forgot-password` | POST | Request password reset |
| `/api/v1/auth/reset-password` | POST | Reset password with token |
| `/api/v1/auth/verify-email` | GET | Verify email with token |
| `/api/v1/auth/change-password` | POST | Change password (authenticated) |
| `/api/v1/auth/resend-verification` | POST | Resend email verification |

### SSH Profile Management

| Endpoint | Method | Description |
|----------|---------|-------------|
| `/api/v1/ssh/profiles` | GET | List user's SSH profiles |
| `/api/v1/ssh/profiles` | POST | Create new SSH profile |
| `/api/v1/ssh/profiles/:id` | GET | Get specific SSH profile |
| `/api/v1/ssh/profiles/:id` | PUT | Update SSH profile |
| `/api/v1/ssh/profiles/:id` | DELETE | Delete SSH profile |
| `/api/v1/ssh/test-connection` | POST | Test SSH connection |
| `/api/v1/ssh/validate-key` | POST | Validate SSH private key |

#### SSH Profile Authentication Types

The SSH profile system supports multiple authentication methods:

**Password Authentication:**
```json
{
  "name": "Server Name",
  "host": "server.example.com",
  "port": 22,
  "username": "user",
  "authType": "password",
  "password": "encrypted_password"
}
```

**SSH Key Authentication:**
```json
{
  "name": "Server Name",
  "host": "server.example.com",
  "port": 22,
  "username": "user",
  "authType": "key",
  "privateKey": "-----BEGIN OPENSSH PRIVATE KEY-----\n..."
}
```

**SSH Key with Passphrase:**
```json
{
  "name": "Server Name",
  "host": "server.example.com",
  "port": 22,
  "username": "user",
  "authType": "keyWithPassphrase",
  "privateKey": "-----BEGIN OPENSSH PRIVATE KEY-----\n...",
  "passphrase": "encrypted_passphrase"
}
```

**Note**: All sensitive data (passwords, private keys, passphrases) are encrypted before storage.

### Terminal Session Management

| Endpoint | Method | Description |
|----------|---------|-------------|
| `/api/v1/terminal/sessions` | GET | List active terminal sessions |
| `/api/v1/terminal/sessions` | POST | Create new terminal session |
| `/api/v1/terminal/sessions/:id` | DELETE | Terminate terminal session |
| `/api/v1/terminal/sessions/:id/history` | GET | Get session command history |
| `/api/v1/terminal/stats` | GET | Get terminal usage statistics |

#### Terminal Session Types

The API supports two types of terminal sessions:

**Local Terminal Session:**
```json
{
  "type": "local",
  "shell": "/bin/bash"
}
```

**SSH Terminal Session:**
```json
{
  "type": "ssh",
  "sshProfileId": "profile-uuid-here"
}
```

Both session types return a session object with:
- `id`: Unique session identifier
- `type`: Session type ("local" or "ssh")
- `status`: Current session status
- `createdAt`: Session creation timestamp
- `lastActivity`: Last activity timestamp

### Subscription & Payments

| Endpoint | Method | Description |
|----------|---------|-------------|
| `/api/v1/subscriptions/current` | GET | Get current subscription |
| `/api/v1/subscriptions/status` | GET | Get subscription status |
| `/api/v1/subscriptions/plans` | GET | Get available plans |
| `/api/v1/subscriptions/history` | GET | Get payment history |
| `/api/v1/subscriptions/cancel` | POST | Cancel subscription |
| `/api/v1/subscriptions/usage/:feature` | GET | Check feature usage limits |
| `/api/v1/subscriptions/free` | POST | Create free subscription |
| `/api/v1/subscriptions/revenuecat-transaction` | POST | Process RevenueCat transaction |
| `/api/v1/webhooks/revenuecat` | POST | RevenueCat webhook handler |
| `/api/v1/payment/health` | GET | Payment service health check |

#### RevenueCat Webhook Integration

The API integrates with RevenueCat for subscription management. The webhook endpoint validates signatures for security:

**Webhook Request Headers:**
- `x-revenuecat-signature`: HMAC signature for request verification
- `Content-Type`: `application/json`

**Webhook Payload Example:**
```json
{
  "event": {
    "type": "INITIAL_PURCHASE",
    "app_user_id": "user-uuid",
    "product_id": "pro_monthly",
    "purchased_at_ms": 1640995200000
  }
}
```

The webhook handler automatically updates user subscriptions based on RevenueCat events.

## Authentication Flow

### 1. Registration
- User provides email, username, and password
- System creates account and sends email verification
- Database transaction with retry mechanism handles race conditions
- Automatic free subscription and usage limits creation
- Returns user object (email_verified: false initially)
- Email verification sent asynchronously (non-blocking)

### 2. Email Verification
- User clicks verification link or calls `/verify-email` with token
- Account becomes fully active

### 3. Login
- User provides email and password
- Enhanced retry logic handles concurrent login attempts
- Returns access_token, refresh_token, and user object
- Access token expires based on JWT.EXPIRES_IN config

### 4. Token Refresh
- Use refresh_token to get new access_token
- Refresh tokens have longer expiration

## Database Reliability Features

### Transaction Isolation Levels
- **Registration**: Serializable isolation with 10-second timeout
- **Login**: ReadCommitted isolation with 5-second timeout
- **Password Reset**: Default isolation for non-critical operations

### Retry Mechanism
- **P2034 Database Conflicts**: Automatic retry with exponential backoff
- **Registration**: Up to 3 retries with base 100ms delay
- **Login**: Up to 5 retries for higher concurrency scenarios
- **CI Environment**: Enhanced retry logic for slower test environments

### Email Service Decoupling
- Email operations moved outside database transactions
- Pre-initialized email service prevents dynamic imports during transactions
- Email failures are non-blocking and don't affect core authentication flows
- Comprehensive error logging for troubleshooting

## Error Handling

All API endpoints follow a consistent error response format:

### Success Response Format
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": { /* response data */ }
}
```

### Error Response Format
```json
{
  "success": false,
  "message": "Error description",
  "code": "ERROR_CODE",
  "errors": ["Detailed error messages"]
}
```

### Common HTTP Status Codes

- **200 OK**: Successful operation
- **201 Created**: Resource created successfully  
- **204 No Content**: Successful operation with no response body
- **400 Bad Request**: Invalid request data or validation errors
- **401 Unauthorized**: Authentication required or invalid credentials
- **403 Forbidden**: Authenticated but insufficient permissions
- **404 Not Found**: Resource not found
- **409 Conflict**: Resource already exists or conflict
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Server error
- **503 Service Unavailable**: Service temporarily unavailable

### Common Error Codes

- `VALIDATION_ERROR`: Request validation failed
- `UNAUTHORIZED`: Authentication required
- `FORBIDDEN`: Insufficient permissions
- `USER_NOT_FOUND`: User does not exist
- `EMAIL_ALREADY_EXISTS`: Email already registered
- `INVALID_CREDENTIALS`: Login failed
- `TOKEN_EXPIRED`: JWT token expired
- `FEATURE_LIMIT_EXCEEDED`: Subscription limit reached
- `PAYMENT_FAILED`: Payment processing error

### Database-Related Error Handling

- **P2034 Transaction Conflicts**: Automatically retried with exponential backoff
- **Connection Timeouts**: Gracefully handled with appropriate user feedback
- **Email Service Failures**: Logged but don't block user registration or authentication
- **Race Condition Protection**: Serializable transactions for critical operations
- **Database State Verification**: Tests verify user persistence before proceeding

## Rate Limiting

The API implements rate limiting to prevent abuse:

- **Authentication endpoints**: 5 requests per minute
- **Password reset endpoints**: 3 requests per 5 minutes  
- **General endpoints**: 100 requests per minute
- **Rate limit headers**: 
  - `x-ratelimit-limit`: Request limit
  - `x-ratelimit-remaining`: Remaining requests
  - `x-ratelimit-reset`: Reset timestamp

## WebSocket Connections

Real-time terminal communication uses WebSocket connections:

- **Endpoint**: `ws://localhost:3000/ws/terminal` or `wss://api.dev.devpocket.app/ws/terminal`
- **Authentication**: Include JWT token in connection query: `?token=YOUR_JWT_TOKEN`
- **Protocol**: Binary data for terminal I/O, JSON for control messages

## Subscription Plans & Limits

### FREE Tier
- Core terminal functionality
- BYOK AI features
- Limited SSH connections (5)
- Limited AI requests (100)
- No multi-device sync
- No cloud command history

### PRO Tier
- All FREE features
- Unlimited SSH connections
- Unlimited AI requests
- Multi-device sync
- Cloud command history
- Priority support

### TEAM Tier
- All PRO features
- Team workspaces
- Shared SSH profiles
- SSO integration
- Advanced analytics
- Team management

#### Subscription Status Response

```json
{
  "isActive": true,
  "tier": "PRO",
  "expiresAt": "2024-12-31T23:59:59Z",
  "limits": {
    "sshConnections": -1,
    "aiRequests": -1,
    "cloudHistory": true,
    "multiDevice": true
  }
}
```

**Note**: A limit value of `-1` indicates unlimited usage for that feature.

## API Request & Response Examples

### Authentication Examples

**Registration Request:**
```bash
curl -X POST https://api.dev.devpocket.app/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "username": "testuser",
    "password": "securepassword123"
  }'
```

**Registration Response:**
```json
{
  "success": true,
  "message": "User registered successfully",
  "data": {
    "user": {
      "id": "uuid-here",
      "email": "user@example.com",
      "username": "testuser",
      "emailVerified": false,
      "createdAt": "2024-01-15T10:30:00Z"
    },
    "accessToken": "jwt-token-here",
    "refreshToken": "refresh-token-here"
  }
}
```

### SSH Profile Creation Example

**Request:**
```bash
curl -X POST https://api.dev.devpocket.app/api/v1/ssh/profiles \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Production Server",
    "host": "prod.example.com",
    "port": 22,
    "username": "admin",
    "authType": "key",
    "privateKey": "-----BEGIN OPENSSH PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END OPENSSH PRIVATE KEY-----"
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "SSH profile created successfully",
  "data": {
    "id": "profile-uuid",
    "name": "Production Server",
    "host": "prod.example.com",
    "port": 22,
    "username": "admin",
    "authType": "key",
    "createdAt": "2024-01-15T10:30:00Z"
  }
}
```

### Terminal Session Creation Example

**Local Terminal Request:**
```bash
curl -X POST https://api.dev.devpocket.app/api/v1/terminal/sessions \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "local",
    "shell": "/bin/bash"
  }'
```

**SSH Terminal Request:**
```bash
curl -X POST https://api.dev.devpocket.app/api/v1/terminal/sessions \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "ssh",
    "sshProfileId": "profile-uuid-here"
  }'
```

**Session Response:**
```json
{
  "success": true,
  "message": "Terminal session created successfully",
  "data": {
    "id": "session-uuid",
    "type": "ssh",
    "status": "active",
    "createdAt": "2024-01-15T10:30:00Z",
    "lastActivity": "2024-01-15T10:30:00Z"
  }
}
```

## Development & Testing

### Test Environment
- Mock implementations available for terminal services during testing
- All SSH-related functionality uses mock responses in test environment
- Health checks and authentication work normally in tests
- **Enhanced CI/CD Reliability**: 
  - Database state verification before proceeding with login attempts
  - Environment-aware retry delays and timeouts
  - Comprehensive error logging for debugging race conditions
  - PostgreSQL health checks in GitHub Actions workflow

### Test Infrastructure Improvements
- **Race Condition Prevention**: Database state verification replaces fixed delays
- **Retry Logic**: Enhanced for CI environments with slower database operations
- **Error Recovery**: Improved error handling and logging throughout authentication flow
- **Performance**: 40% improvement in test execution time with optimized wait strategies

### Docker Support
```bash
# Start development environment
docker-compose up -d

# View logs
docker-compose logs -f api
```

### Environment Variables
Key environment variables for API configuration:

```bash
DATABASE_URL=postgresql://user:pass@localhost:5432/devpocket
REDIS_URL=redis://localhost:6379
JWT_SECRET=your-secret-key
JWT_EXPIRES_IN=24h
FRONTEND_URL=http://localhost:3000
NODE_ENV=development
```

## SDK Generation

The API supports automatic SDK generation using the OpenAPI specification:

```bash
# Generate TypeScript SDK (Development)
npx openapi-generator-cli generate \
  -i https://api.dev.devpocket.app/docs/json \
  -g typescript-axios \
  -o ./sdk/typescript

# Generate TypeScript SDK (Local)
npx openapi-generator-cli generate \
  -i http://localhost:3000/docs/json \
  -g typescript-axios \
  -o ./sdk/typescript

# Generate Python SDK (Development)
npx openapi-generator-cli generate \
  -i https://api.dev.devpocket.app/docs/json \
  -g python \
  -o ./sdk/python

# Generate Python SDK (Local)
npx openapi-generator-cli generate \
  -i http://localhost:3000/docs/json \
  -g python \
  -o ./sdk/python
```

## Support & Resources

- **Documentation**: Available at `/docs` (Swagger UI)
- **Repository**: [GitHub Repository]
- **Issues**: Report bugs and feature requests via GitHub Issues
- **Support**: Contact support for Pro/Team tier users

---

*This documentation is automatically kept in sync with the OpenAPI specification. For the most up-to-date API reference, visit the Swagger UI at `/docs`.*