"""Civic-Link DPI - Alembic Environment Configuration

Supports both online and offline migration modes.
Imports all models so Alembic can detect schema changes via autogenerate.
"""

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

# Import Base and all models so Alembic can detect them
from app.models.base import BaseModel
from app.models.user import User, UserRole, Gender, VerificationStatus
from app.models.commute import Commute, CommuteOffer, CommuteStatus, CommuteType, WeekDay
from app.models.match import CommuteMatch, MatchStatus, PaymentStatus
from app.models.civic_score import CivicScore, CivicScoreHistory
from app.models.audit import CommuteAuditLog, SafetyAlertLog, AuditEventType, AuditEventSeverity

# Alembic Config object
config = context.config

# Interpret the config file for Python logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Target metadata for autogenerate
target_metadata = BaseModel.metadata

# Override sqlalchemy.url from environment if not set in alembic.ini
import os

# Schemas to ignore (PostGIS extension tables)
IGNORED_SCHEMAS = {"tiger", "tiger_data", "topology", "public"}

# Tables to ignore (PostGIS internal tables in public schema)
IGNORED_TABLES = {
    "spatial_ref_sys",
    "geography_columns",
    "geometry_columns",
}


def get_url():
    """Get database URL from environment or config."""
    env_url = os.environ.get("DATABASE_URL")
    if env_url:
        if env_url.startswith("postgres://"):
            env_url = env_url.replace("postgres://", "postgresql+asyncpg://", 1)
        elif env_url.startswith("postgresql://") and not env_url.startswith("postgresql+asyncpg://"):
            env_url = env_url.replace("postgresql://", "postgresql+asyncpg://", 1)
        return env_url
    return config.get_main_option("sqlalchemy.url")


def include_name(name, type_, parent_names):
    """Filter out PostGIS extension objects from autogenerate by name."""
    if name is None:
        return True
    # Skip PostGIS internal tables
    if type_ == "table" and name in IGNORED_TABLES:
        return False
    return True


def include_object(object, name, type_, reflected, compare_to):
    """Filter out PostGIS extension objects from autogenerate."""
    # Skip objects in PostGIS schemas
    if type_ in ("table", "index", "schema"):
        schema = getattr(object, "schema", None)
        if schema in ("tiger", "tiger_data", "topology"):
            return False

    # Skip PostGIS internal tables in public schema
    if type_ == "table" and name in IGNORED_TABLES:
        return False

    # Skip indexes on PostGIS tables
    if type_ == "index" and compare_to is not None:
        table_name = getattr(compare_to.table, "name", None) if hasattr(compare_to, "table") else None
        if table_name in IGNORED_TABLES:
            return False

    return True


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode.

    Generates SQL scripts without connecting to the database.
    Useful for DBA review or environments without direct DB access.
    """
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        include_object=include_object,
        include_name=include_name,
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    """Run migrations with the given connection."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        include_object=include_object,
        include_name=include_name,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Run migrations in 'online' mode with async engine."""
    configuration = config.get_section(config.config_ini_section)
    configuration["sqlalchemy.url"] = get_url()

    connectable = async_engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""
    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
