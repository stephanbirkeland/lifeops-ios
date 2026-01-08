"""
FastAPI exception handlers for consistent error responses.

Registers handlers for custom exceptions and standard HTTP errors,
ensuring all errors are returned in a consistent JSON format.
"""

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError
from starlette.exceptions import HTTPException as StarletteHTTPException
from pydantic import ValidationError as PydanticValidationError

from app.core.exceptions import APIError
from app.core.logging import get_logger, get_correlation_id

logger = get_logger(__name__)


async def api_error_handler(request: Request, exc: APIError) -> JSONResponse:
    """Handle custom API errors."""
    correlation_id = get_correlation_id()

    logger.warning(
        f"API error: {exc.error_code} - {exc.message}",
        extra={
            "error_code": exc.error_code,
            "status_code": exc.status_code,
            "path": str(request.url.path),
            "method": request.method,
            "details": exc.details,
        },
    )

    response_data = exc.to_dict()
    if correlation_id:
        response_data["error"]["correlation_id"] = correlation_id

    return JSONResponse(
        status_code=exc.status_code,
        content=response_data,
    )


async def http_exception_handler(
    request: Request, exc: StarletteHTTPException
) -> JSONResponse:
    """Handle standard HTTP exceptions."""
    correlation_id = get_correlation_id()

    logger.warning(
        f"HTTP error: {exc.status_code} - {exc.detail}",
        extra={
            "status_code": exc.status_code,
            "path": str(request.url.path),
            "method": request.method,
        },
    )

    response_data = {
        "error": {
            "code": "HTTP_ERROR",
            "message": str(exc.detail),
            "details": {},
        }
    }
    if correlation_id:
        response_data["error"]["correlation_id"] = correlation_id

    return JSONResponse(
        status_code=exc.status_code,
        content=response_data,
    )


async def validation_exception_handler(
    request: Request, exc: RequestValidationError
) -> JSONResponse:
    """Handle Pydantic validation errors from request parsing."""
    correlation_id = get_correlation_id()

    # Format validation errors for clarity
    errors = []
    for error in exc.errors():
        errors.append({
            "field": ".".join(str(loc) for loc in error["loc"]),
            "message": error["msg"],
            "type": error["type"],
        })

    logger.warning(
        f"Validation error: {len(errors)} field(s) failed validation",
        extra={
            "path": str(request.url.path),
            "method": request.method,
            "errors": errors,
        },
    )

    response_data = {
        "error": {
            "code": "VALIDATION_ERROR",
            "message": "Request validation failed",
            "details": {"errors": errors},
        }
    }
    if correlation_id:
        response_data["error"]["correlation_id"] = correlation_id

    return JSONResponse(
        status_code=422,
        content=response_data,
    )


async def pydantic_validation_handler(
    request: Request, exc: PydanticValidationError
) -> JSONResponse:
    """Handle Pydantic validation errors from internal operations."""
    correlation_id = get_correlation_id()

    errors = []
    for error in exc.errors():
        errors.append({
            "field": ".".join(str(loc) for loc in error["loc"]),
            "message": error["msg"],
            "type": error["type"],
        })

    logger.error(
        f"Internal validation error: {len(errors)} field(s) failed",
        extra={
            "path": str(request.url.path),
            "method": request.method,
            "errors": errors,
        },
    )

    response_data = {
        "error": {
            "code": "INTERNAL_VALIDATION_ERROR",
            "message": "Data validation failed",
            "details": {"errors": errors},
        }
    }
    if correlation_id:
        response_data["error"]["correlation_id"] = correlation_id

    return JSONResponse(
        status_code=500,
        content=response_data,
    )


async def unhandled_exception_handler(
    request: Request, exc: Exception
) -> JSONResponse:
    """Handle any unhandled exceptions."""
    correlation_id = get_correlation_id()

    logger.exception(
        f"Unhandled exception: {type(exc).__name__}: {exc}",
        extra={
            "path": str(request.url.path),
            "method": request.method,
            "exception_type": type(exc).__name__,
        },
    )

    response_data = {
        "error": {
            "code": "INTERNAL_ERROR",
            "message": "An unexpected error occurred",
            "details": {},
        }
    }
    if correlation_id:
        response_data["error"]["correlation_id"] = correlation_id

    return JSONResponse(
        status_code=500,
        content=response_data,
    )


def register_exception_handlers(app: FastAPI) -> None:
    """
    Register all exception handlers with the FastAPI application.

    Args:
        app: FastAPI application instance.
    """
    app.add_exception_handler(APIError, api_error_handler)
    app.add_exception_handler(StarletteHTTPException, http_exception_handler)
    app.add_exception_handler(RequestValidationError, validation_exception_handler)
    app.add_exception_handler(PydanticValidationError, pydantic_validation_handler)
    app.add_exception_handler(Exception, unhandled_exception_handler)
