# Digest

## Global Exception Handler

This project implements a centralized exception handling mechanism using Spring's `@ControllerAdvice` annotation. All exceptions thrown throughout the application are caught and standardized into a consistent error response format.

### Architecture

The exception handler is located in `com.example.digest.exception.handler` package and consists of three components:

#### 1. **ErrorCode** (`ErrorCode.java`)
An enum that defines standardized error codes for different exception scenarios:
- `DUPLICATE_EMAIL (1001)` - Email already registered
- `USER_NOT_FOUND (1002)` - User not found
- `VALIDATION_ERROR (1003)` - Request validation failed
- `INTERNAL_SERVER_ERROR (1004)` - Unexpected server error

#### 2. **ErrorResponse** (`ErrorResponse.java`)
A DTO that represents the standardized error response structure:
- `timestamp` - ISO-8601 timestamp when the error occurred
- `status` - HTTP status code
- `error` - HTTP error reason phrase (e.g., "CONFLICT", "BAD_REQUEST")
- `message` - User-friendly error message
- `path` - Request URI path
- `method` - HTTP method (GET, POST, etc.)
- `fieldErrors` - List of validation field errors (only for validation failures)
- `details` - Additional error details (only shown in dev profile for debugging)

#### 3. **GlobalExceptionHandler** (`GlobalExceptionHandler.java`)
The `@ControllerAdvice` class that intercepts and handles all exceptions:

| Exception | HTTP Status | Log Level | Description |
|-----------|-------------|-----------|-------------|
| `DuplicateEmailException` | 409 Conflict | WARN | Email already registered |
| `UserNotFoundException` | 404 Not Found | INFO | User not found |
| `MethodArgumentNotValidException` | 400 Bad Request | DEBUG | Request validation failed (includes all field errors) |
| `HttpMessageNotReadableException` | 400 Bad Request | WARN | Invalid request body format |
| `Exception` (catch-all) | 500 Internal Server Error | ERROR | Unexpected errors |

### Error Response Examples

#### Duplicate Email (409 Conflict)
```json
{
  "timestamp": "2026-04-27T10:40:32",
  "status": 409,
  "error": "CONFLICT",
  "message": "Email is already registered.",
  "path": "/api/v1",
  "method": "POST"
}
```

#### Validation Error (400 Bad Request)
```json
{
  "timestamp": "2026-04-27T10:40:32",
  "status": 400,
  "error": "BAD_REQUEST",
  "message": "Validation failed.",
  "path": "/api/v1",
  "method": "POST",
  "fieldErrors": [
    {
      "field": "email",
      "message": "Formato do e-mail inválido",
      "rejectedValue": "invalid-email"
    }
  ]
}
```

#### User Not Found (404 Not Found)
```json
{
  "timestamp": "2026-04-27T10:40:32",
  "status": 404,
  "error": "NOT_FOUND",
  "message": "User not found.",
  "path": "/api/v1/user/999",
  "method": "GET"
}
```

### Profile-Based Behavior

- **Development Profile (`dev`, `development`)**: The `details` field includes exception class name and message for debugging purposes
- **Production Profile**: The `details` field is omitted for security reasons

Set the active profile in `application.properties`:
```properties
spring.profiles.active=dev
```

### Features

✅ Centralized exception handling  
✅ Standardized error response format  
✅ All validation errors returned at once  
✅ Request context included (path, method, timestamp)  
✅ Environment-aware sensitive data handling  
✅ Appropriate HTTP status codes and log levels  
✅ No changes required to existing controllers or services
