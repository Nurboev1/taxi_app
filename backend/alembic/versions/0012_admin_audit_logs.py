"""add admin audit logs table

Revision ID: 0012_admin_audit_logs
Revises: 0011_admin_roles_and_status
Create Date: 2026-03-07
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0012_admin_audit_logs"
down_revision: Union[str, None] = "0011_admin_roles_and_status"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "admin_audit_logs",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("actor_username", sa.String(length=100), nullable=False),
        sa.Column("action", sa.String(length=64), nullable=False),
        sa.Column("target_username", sa.String(length=100), nullable=True),
        sa.Column("details", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_admin_audit_logs_actor_username",
        "admin_audit_logs",
        ["actor_username"],
        unique=False,
    )
    op.create_index(
        "ix_admin_audit_logs_action",
        "admin_audit_logs",
        ["action"],
        unique=False,
    )
    op.create_index(
        "ix_admin_audit_logs_target_username",
        "admin_audit_logs",
        ["target_username"],
        unique=False,
    )
    op.create_index(
        "ix_admin_audit_logs_created_at",
        "admin_audit_logs",
        ["created_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_admin_audit_logs_created_at", table_name="admin_audit_logs")
    op.drop_index("ix_admin_audit_logs_target_username", table_name="admin_audit_logs")
    op.drop_index("ix_admin_audit_logs_action", table_name="admin_audit_logs")
    op.drop_index("ix_admin_audit_logs_actor_username", table_name="admin_audit_logs")
    op.drop_table("admin_audit_logs")
