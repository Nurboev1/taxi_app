"""add admin audit log metadata columns

Revision ID: 0016_admin_audit_log_metadata
Revises: 0015_request_seat_mix
Create Date: 2026-03-08
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0016_admin_audit_log_metadata"
down_revision: Union[str, None] = "0015_request_seat_mix"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("admin_audit_logs", sa.Column("actor_ip", sa.String(length=128), nullable=True))
    op.add_column("admin_audit_logs", sa.Column("request_id", sa.String(length=128), nullable=True))
    op.add_column("admin_audit_logs", sa.Column("actor_user_agent", sa.String(length=512), nullable=True))
    op.add_column("admin_audit_logs", sa.Column("before_state", sa.Text(), nullable=True))
    op.add_column("admin_audit_logs", sa.Column("after_state", sa.Text(), nullable=True))

    op.create_index(
        "ix_admin_audit_logs_actor_ip",
        "admin_audit_logs",
        ["actor_ip"],
        unique=False,
    )
    op.create_index(
        "ix_admin_audit_logs_request_id",
        "admin_audit_logs",
        ["request_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_admin_audit_logs_request_id", table_name="admin_audit_logs")
    op.drop_index("ix_admin_audit_logs_actor_ip", table_name="admin_audit_logs")

    op.drop_column("admin_audit_logs", "after_state")
    op.drop_column("admin_audit_logs", "before_state")
    op.drop_column("admin_audit_logs", "actor_user_agent")
    op.drop_column("admin_audit_logs", "request_id")
    op.drop_column("admin_audit_logs", "actor_ip")
