"""
Custom exceptions for LifeOps API.

Provides a hierarchy of application-specific exceptions that can be
caught and handled consistently across the API.
"""

from typing import Any


class APIError(Exception):
    """
    Base exception for all API errors.

    Attributes:
        message: Human-readable error message.
        status_code: HTTP status code to return.
        error_code: Machine-readable error code for clients.
        details: Additional error details.
    """

    def __init__(
        self,
        message: str,
        status_code: int = 500,
        error_code: str = "INTERNAL_ERROR",
        details: dict[str, Any] | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.status_code = status_code
        self.error_code = error_code
        self.details = details or {}

    def to_dict(self) -> dict[str, Any]:
        """Convert exception to dictionary for JSON response."""
        return {
            "error": {
                "code": self.error_code,
                "message": self.message,
                "details": self.details,
            }
        }


class NotFoundError(APIError):
    """Raised when a requested resource is not found."""

    def __init__(
        self,
        message: str = "Resource not found",
        resource_type: str | None = None,
        resource_id: str | None = None,
    ) -> None:
        details = {}
        if resource_type:
            details["resource_type"] = resource_type
        if resource_id:
            details["resource_id"] = resource_id

        super().__init__(
            message=message,
            status_code=404,
            error_code="NOT_FOUND",
            details=details,
        )


class ValidationError(APIError):
    """Raised when request validation fails."""

    def __init__(
        self,
        message: str = "Validation failed",
        field: str | None = None,
        errors: list[dict[str, Any]] | None = None,
    ) -> None:
        details: dict[str, Any] = {}
        if field:
            details["field"] = field
        if errors:
            details["errors"] = errors

        super().__init__(
            message=message,
            status_code=422,
            error_code="VALIDATION_ERROR",
            details=details,
        )


class AuthenticationError(APIError):
    """Raised when authentication fails."""

    def __init__(
        self,
        message: str = "Authentication required",
    ) -> None:
        super().__init__(
            message=message,
            status_code=401,
            error_code="AUTHENTICATION_ERROR",
        )


class AuthorizationError(APIError):
    """Raised when user lacks permission for an action."""

    def __init__(
        self,
        message: str = "Permission denied",
        required_permission: str | None = None,
    ) -> None:
        details = {}
        if required_permission:
            details["required_permission"] = required_permission

        super().__init__(
            message=message,
            status_code=403,
            error_code="AUTHORIZATION_ERROR",
            details=details,
        )


class ConflictError(APIError):
    """Raised when an action conflicts with existing state."""

    def __init__(
        self,
        message: str = "Resource conflict",
        conflict_type: str | None = None,
    ) -> None:
        details = {}
        if conflict_type:
            details["conflict_type"] = conflict_type

        super().__init__(
            message=message,
            status_code=409,
            error_code="CONFLICT_ERROR",
            details=details,
        )


class RateLimitError(APIError):
    """Raised when rate limit is exceeded."""

    def __init__(
        self,
        message: str = "Rate limit exceeded",
        retry_after: int | None = None,
    ) -> None:
        details = {}
        if retry_after:
            details["retry_after_seconds"] = retry_after

        super().__init__(
            message=message,
            status_code=429,
            error_code="RATE_LIMIT_ERROR",
            details=details,
        )


class ExternalServiceError(APIError):
    """Raised when an external service (e.g., Oura API) fails."""

    def __init__(
        self,
        message: str = "External service error",
        service: str | None = None,
        original_error: str | None = None,
    ) -> None:
        details = {}
        if service:
            details["service"] = service
        if original_error:
            details["original_error"] = original_error

        super().__init__(
            message=message,
            status_code=502,
            error_code="EXTERNAL_SERVICE_ERROR",
            details=details,
        )


class DatabaseError(APIError):
    """Raised when a database operation fails."""

    def __init__(
        self,
        message: str = "Database operation failed",
        operation: str | None = None,
    ) -> None:
        details = {}
        if operation:
            details["operation"] = operation

        super().__init__(
            message=message,
            status_code=500,
            error_code="DATABASE_ERROR",
            details=details,
        )
