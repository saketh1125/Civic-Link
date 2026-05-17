"""Civic-Link DPI - Structured Logging Configuration

Configures structlog with JSON renderer for production and console
renderer for development. Adds request_id to every log entry.
"""

import logging
import os
import sys
from typing import Any

import structlog


def configure_logging() -> None:
    """Configure structlog based on environment.

    Production: JSON renderer for machine parsing
    Development: Console renderer for human readability
    """
    is_production = os.getenv("ENVIRONMENT", "development") == "production"
    log_level_str = os.getenv("LOG_LEVEL", "INFO").upper()
    log_level = getattr(logging, log_level_str, logging.INFO)

    shared_processors: list[Any] = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.StackInfoRenderer(),
        structlog.dev.set_exc_info,
        structlog.processors.TimeStamper(fmt="iso"),
    ]

    if is_production:
        renderer = structlog.processors.JSONRenderer()
    else:
        renderer = structlog.dev.ConsoleRenderer()

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.processors.dict_tracebacks,
            renderer,
        ],
        wrapper_class=structlog.make_filtering_bound_logger(log_level),
        context_class=dict,
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(*args: Any, **kwargs: Any) -> Any:
    """Get a structlog logger instance.

    Args:
        *args: Optional positional args for logger naming
        **kwargs: Optional initial context

    Returns:
        Configured structlog logger
    """
    return structlog.get_logger(*args, **kwargs)
