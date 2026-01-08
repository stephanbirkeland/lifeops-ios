# Authentication Guide

The LifeOps API uses **JWT (JSON Web Tokens)** for authentication. This provides secure, stateless authentication with short-lived access tokens and long-lived refresh tokens.

## Table of Contents

- [Quick Start](#quick-start)
- [Authentication Flow](#authentication-flow)
- [Token Types](#token-types)
- [Endpoints](#endpoints)
- [Using Authentication](#using-authentication)
- [Security Best Practices](#security-best-practices)
- [Configuration](#configuration)
- [Testing](#testing)

## Quick Start

### 1. Register a New User

```bash
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "email": "john@example.com",
    "password": "SecurePassword123!"
  }'
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "username": "johndoe",
  "email": "john@example.com",
  "is_active": true,
  "is_superuser": false,
  "created_at": "2026-01-08T12:00:00Z",
  "updated_at": "2026-01-08T12:00:00Z",
  "last_login": null
}
```

### 2. Login

```bash
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "johndoe",
    "password": "SecurePassword123!"
  }'
```

Response:
```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "bearer"
}
```

### 3. Access Protected Endpoint

```bash
curl http://localhost:8000/auth/me \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

## Authentication Flow

```
┌─────────────┐                  ┌─────────────┐
│   Client    │                  │     API     │
└──────┬──────┘                  └──────┬──────┘
       │                                │
       │  1. POST /auth/register        │
       │─────────────────────────────>  │
       │                                │
       │  2. POST /auth/login           │
       │     (username, password)       │
       │─────────────────────────────>  │
       │                                │
       │  3. Tokens                     │
       │     (access + refresh)         │
       │  <─────────────────────────────│
       │                                │
       │  4. GET /protected             │
       │     Authorization: Bearer      │
       │─────────────────────────────>  │
       │                                │
       │  5. Protected Resource         │
       │  <─────────────────────────────│
       │                                │
       │  (After 15 min)                │
       │                                │
       │  6. POST /auth/refresh         │
       │     (refresh_token)            │
       │─────────────────────────────>  │
       │                                │
       │  7. New Tokens                 │
       │  <─────────────────────────────│
       │                                │
```

## Token Types

### Access Token
- **Purpose**: Used for API requests
- **Lifetime**: 15 minutes (default)
- **Usage**: Include in `Authorization` header
- **Format**: `Bearer <access_token>`

### Refresh Token
- **Purpose**: Used to obtain new access tokens
- **Lifetime**: 7 days (default)
- **Usage**: Send to `/auth/refresh` endpoint
- **Security**: Store securely, never expose in URL

## Endpoints

### POST /auth/register

Register a new user account.

**Request Body:**
```json
{
  "username": "string (3-50 chars)",
  "email": "valid email",
  "password": "string (min 8 chars)"
}
```

**Responses:**
- `201 Created`: User created successfully
- `400 Bad Request`: Username or email already exists
- `422 Unprocessable Entity`: Validation error

### POST /auth/login

Authenticate and receive tokens.

**Request Body:**
```json
{
  "username": "string",
  "password": "string"
}
```

**Responses:**
- `200 OK`: Returns access and refresh tokens
- `401 Unauthorized`: Invalid credentials
- `403 Forbidden`: Account is inactive

### POST /auth/refresh

Get new tokens using refresh token.

**Request Body:**
```json
{
  "refresh_token": "string"
}
```

**Responses:**
- `200 OK`: Returns new access and refresh tokens
- `401 Unauthorized`: Invalid or expired refresh token
- `403 Forbidden`: Account is inactive

**Important**: The old refresh token becomes invalid after use (token rotation).

### GET /auth/me

Get current user information.

**Authentication**: Required

**Responses:**
- `200 OK`: Returns user object
- `401 Unauthorized`: Invalid or missing token
- `403 Forbidden`: Account is inactive

### POST /auth/change-password

Change current user's password.

**Authentication**: Required

**Request Body:**
```json
{
  "current_password": "string",
  "new_password": "string (min 8 chars)"
}
```

**Responses:**
- `204 No Content`: Password changed successfully
- `401 Unauthorized`: Current password incorrect or invalid token
- `422 Unprocessable Entity`: Validation error

### POST /auth/logout

Logout current user (client-side token deletion).

**Authentication**: Required

**Responses:**
- `204 No Content`: Success
- `401 Unauthorized`: Invalid token

**Note**: Since JWTs are stateless, logout is primarily client-side. Delete tokens from storage after calling this endpoint.

## Using Authentication

### In cURL

```bash
# Store token in variable
TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# Use in requests
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/auth/me
```

### In Python (httpx)

```python
import httpx

# Login
async with httpx.AsyncClient() as client:
    response = await client.post(
        "http://localhost:8000/auth/login",
        json={"username": "johndoe", "password": "SecurePassword123!"}
    )
    tokens = response.json()
    access_token = tokens["access_token"]

    # Use token
    headers = {"Authorization": f"Bearer {access_token}"}
    response = await client.get(
        "http://localhost:8000/auth/me",
        headers=headers
    )
    user = response.json()
```

### In JavaScript (fetch)

```javascript
// Login
const loginResponse = await fetch('http://localhost:8000/auth/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    username: 'johndoe',
    password: 'SecurePassword123!'
  })
});

const { access_token, refresh_token } = await loginResponse.json();

// Store tokens (use httpOnly cookies in production)
localStorage.setItem('access_token', access_token);
localStorage.setItem('refresh_token', refresh_token);

// Use token
const response = await fetch('http://localhost:8000/auth/me', {
  headers: {
    'Authorization': `Bearer ${access_token}`
  }
});

const user = await response.json();
```

### In FastAPI Dependencies

```python
from fastapi import APIRouter, Depends
from app.core.security.dependencies import get_current_user, get_current_superuser
from app.models.auth import User

router = APIRouter()

# Require authentication
@router.get("/protected")
async def protected_route(current_user: User = Depends(get_current_user)):
    return {"message": f"Hello {current_user.username}"}

# Require superuser
@router.delete("/admin/users/{user_id}")
async def delete_user(
    user_id: UUID,
    admin: User = Depends(get_current_superuser)
):
    # Only superusers can access
    pass

# Optional authentication
from app.core.security.dependencies import get_optional_user

@router.get("/posts")
async def list_posts(user: Optional[User] = Depends(get_optional_user)):
    if user:
        return get_personalized_posts(user.id)
    else:
        return get_public_posts()
```

## Security Best Practices

### Token Storage

**Client-Side:**
- ✅ **Recommended**: HttpOnly cookies (most secure)
- ⚠️ **Acceptable**: localStorage (vulnerable to XSS)
- ❌ **Never**: URL parameters or visible in logs

**Server-Side:**
- Tokens are stateless and not stored on server
- Optional: Implement token revocation list in Redis

### Password Requirements

- Minimum 8 characters
- Consider adding complexity requirements in production:
  - Uppercase + lowercase letters
  - Numbers
  - Special characters
  - Check against common password lists

### Token Expiration

**Current Defaults:**
- Access Token: 15 minutes
- Refresh Token: 7 days

**Production Recommendations:**
- Keep access tokens short-lived (15-30 min)
- Refresh tokens: 7-30 days depending on security needs
- Implement automatic token refresh before expiration

### HTTPS Only

⚠️ **CRITICAL**: Always use HTTPS in production to prevent token interception.

### Rate Limiting

Consider implementing rate limiting on auth endpoints:
- `/auth/login`: Prevent brute force attacks
- `/auth/register`: Prevent spam registrations
- `/auth/refresh`: Prevent token abuse

### Token Rotation

Refresh tokens are automatically rotated on refresh. Old refresh tokens become invalid after use, providing better security.

## Configuration

### Environment Variables

```bash
# .env file
JWT_SECRET=your-secret-key-here-change-in-production
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=7
```

### Generate Secure Secret

```bash
# Using OpenSSL
openssl rand -hex 32

# Using Python
python -c "import secrets; print(secrets.token_hex(32))"
```

### Settings (app/core/config.py)

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    jwt_secret: str  # Must be kept secret!
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 15
    refresh_token_expire_days: int = 7
```

## Testing

### Run Auth Tests

```bash
# Unit tests (security utilities)
pytest tests/unit/test_auth_security.py -v

# Integration tests (full auth flow)
pytest tests/integration/test_auth.py -v

# All auth tests
pytest tests/ -k auth -v
```

### Test Coverage

```bash
pytest --cov=app.core.security --cov=app.routers.auth tests/
```

### Manual Testing with Swagger UI

1. Start the API: `uvicorn app.main:app --reload`
2. Open http://localhost:8000/docs
3. Register a user via `/auth/register`
4. Login via `/auth/login` (copy the access_token)
5. Click "Authorize" button at top right
6. Enter: `Bearer <your_access_token>`
7. Try protected endpoints

## Troubleshooting

### "Could not validate credentials"

- Token is expired (access tokens expire after 15 minutes)
- Token is malformed or tampered with
- JWT_SECRET has changed on server
- **Solution**: Use refresh token to get new access token

### "Inactive user"

- User account has been deactivated (`is_active = false`)
- **Solution**: Contact administrator to reactivate account

### "Username already registered"

- Username is taken
- **Solution**: Choose a different username

### Token expires too quickly

- Increase `ACCESS_TOKEN_EXPIRE_MINUTES` in config
- Implement automatic token refresh in client
- Use refresh token proactively before expiration

## Future Enhancements

Potential improvements for production:

1. **Token Revocation List**
   - Implement Redis-based revocation list
   - Support immediate logout and "logout all devices"

2. **Multi-Factor Authentication (MFA)**
   - TOTP (Time-based One-Time Password)
   - SMS or email verification

3. **OAuth2 Providers**
   - Login with Google, GitHub, Apple
   - Social authentication

4. **Session Management**
   - Track active sessions per user
   - Revoke specific sessions
   - "Logout all devices" feature

5. **Account Security**
   - Password strength meter
   - Breach detection (HaveIBeenPwned API)
   - Account lockout after failed attempts
   - Email verification on registration

6. **Audit Logging**
   - Track login attempts (success/failure)
   - Log IP addresses and user agents
   - Monitor suspicious activity

---

**Security Note**: This authentication system is production-ready but should be reviewed by a security professional before deploying to production with sensitive data. Always use HTTPS and implement rate limiting.
