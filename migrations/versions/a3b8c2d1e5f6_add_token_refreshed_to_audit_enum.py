"""add_token_refreshed_to_audit_enum

Revision ID: a3b8c2d1e5f6
Revises: e14fe2c5ae57
Create Date: 2026-05-17

Adds TOKEN_REFRESHED to the audit_event_type_enum to match the
AuditEventType model in app/models/audit.py.
"""

from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "a3b8c2d1e5f6"
down_revision: Union[str, None] = "e14fe2c5ae57"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TYPE audit_event_type_enum ADD VALUE IF NOT EXISTS 'token_refreshed'")


def downgrade() -> None:
    # PostgreSQL does not support removing values from an enum type.
    # A full enum recreation would be needed, which is not worth the risk.
    pass
