"""
Structured logging configuration for LifeOps API.

Provides JSON logging for production and human-readable format for development.
Includes request correlation IDs for distributed tracing.
"""

import logging
import sys
import json
import uuid
from datetime import datetime, timezone
from contextvars import ContextVar
from typing import Any

from app.core.config import settings

# Context variable for request correlation ID
correlation_id_var: ContextVar[str | None] = ContextVar("correlation_id", default=None)


def get_correlation_id() -> str | None:
    """Get the current request correlation ID."""
    return correlation_id_var.get()


def set_correlation_id(correlation_id: str | None = None) -> str:
    """Set the correlation ID for the current request context."""
    cid = correlation_id or str(uuid.uuid4())
    correlation_id_var.set(cid)
    return cid


class JSONFormatter(logging.Formatter):
    """JSON log formatter for production environments."""

    def format(self, record: logging.LogRecord) -> str:
        log_data: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        # Add correlation ID if available
        correlation_id = get_correlation_id()
        if correlation_id:
            log_data["correlation_id"] = correlation_id

        # Add source location
        log_data["source"] = {
            "file": record.pathname,
            "line": record.lineno,
            "function": record.funcName,
        }

        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)

        # Add any extra attributes
        for key, value in record.__dict__.items():
            if key not in (
                "name", "msg", "args", "created", "filename", "funcName",
                "levelname", "levelno", "lineno", "module", "msecs",
                "pathname", "process", "processName", "relativeCreated",
                "stack_info", "exc_info", "exc_text", "thread", "threadName",
                "taskName", "message",
            ):
                log_data[key] = value

        return json.dumps(log_data, default=str)


class ReadableFormatter(logging.Formatter):
    """Human-readable log formatter for development environments."""

    COLORS = {
        "DEBUG": "\033[36m",     # Cyan
        "INFO": "\033[32m",      # Green
        "WARNING": "\033[33m",   # Yellow
        "ERROR": "\033[31m",     # Red
        "CRITICAL": "\033[35m",  # Magenta
        "RESET": "\033[0m",      # Reset
    }

    def format(self, record: logging.LogRecord) -> str:
        color = self.COLORS.get(record.levelname, self.COLORS["RESET"])
        reset = self.COLORS["RESET"]

        # Build correlation ID prefix
        correlation_id = get_correlation_id()
        cid_str = f"[{correlation_id[:8]}] " if correlation_id else ""

        # Format timestamp
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        # Build the log message
        message = f"{timestamp} {color}{record.levelname:8}{reset} {cid_str}{record.name}: {record.getMessage()}"

        # Add exception info if present
        if record.exc_info:
            message += f"\n{self.formatException(record.exc_info)}"

        return message


def setup_logging() -> None:
    """
    Configure logging for the application.

    Uses JSON format in production, readable format in development.
    """
    # Determine log level
    log_level = logging.DEBUG if settings.debug else logging.INFO
    if settings.environment == "production":
        log_level = logging.INFO

    # Create root logger configuration
    root_logger = logging.getLogger()
    root_logger.setLevel(log_level)

    # Remove existing handlers
    for handler in root_logger.handlers[:]:
        root_logger.removeHandler(handler)

    # Create console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(log_level)

    # Choose formatter based on environment
    if settings.environment == "production":
        formatter = JSONFormatter()
    else:
        formatter = ReadableFormatter()

    console_handler.setFormatter(formatter)
    root_logger.addHandler(console_handler)

    # Reduce noise from third-party libraries
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(
        logging.WARNING if settings.environment == "production" else logging.INFO
    )
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)


def get_logger(name: str) -> logging.Logger:
    """
    Get a logger instance with the given name.

    Args:
        name: Logger name, typically __name__ of the module.

    Returns:
        Configured logger instance.
    """
    return logging.getLogger(name)
