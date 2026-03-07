"""add support tickets and telegram sessions

Revision ID: 0013_support_tickets
Revises: 0012_admin_audit_logs
Create Date: 2026-03-07
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0013_support_tickets"
down_revision: Union[str, None] = "0012_admin_audit_logs"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "support_tickets",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("source", sa.String(length=32), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("phone", sa.String(length=32), nullable=True),
        sa.Column("telegram_chat_id", sa.String(length=64), nullable=True),
        sa.Column("telegram_username", sa.String(length=100), nullable=True),
        sa.Column("subject", sa.String(length=120), nullable=True),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("status", sa.String(length=24), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_support_tickets_source", "support_tickets", ["source"], unique=False)
    op.create_index("ix_support_tickets_user_id", "support_tickets", ["user_id"], unique=False)
    op.create_index("ix_support_tickets_phone", "support_tickets", ["phone"], unique=False)
    op.create_index(
        "ix_support_tickets_telegram_chat_id",
        "support_tickets",
        ["telegram_chat_id"],
        unique=False,
    )
    op.create_index("ix_support_tickets_status", "support_tickets", ["status"], unique=False)
    op.create_index("ix_support_tickets_created_at", "support_tickets", ["created_at"], unique=False)

    op.create_table(
        "telegram_support_sessions",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("chat_id", sa.String(length=64), nullable=False),
        sa.Column("state", sa.String(length=24), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("phone_candidate", sa.String(length=32), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("chat_id", name="uq_telegram_support_sessions_chat_id"),
    )
    op.create_index(
        "ix_telegram_support_sessions_chat_id",
        "telegram_support_sessions",
        ["chat_id"],
        unique=True,
    )
    op.create_index(
        "ix_telegram_support_sessions_state",
        "telegram_support_sessions",
        ["state"],
        unique=False,
    )
    op.create_index(
        "ix_telegram_support_sessions_user_id",
        "telegram_support_sessions",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_telegram_support_sessions_updated_at",
        "telegram_support_sessions",
        ["updated_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_telegram_support_sessions_updated_at", table_name="telegram_support_sessions")
    op.drop_index("ix_telegram_support_sessions_user_id", table_name="telegram_support_sessions")
    op.drop_index("ix_telegram_support_sessions_state", table_name="telegram_support_sessions")
    op.drop_index("ix_telegram_support_sessions_chat_id", table_name="telegram_support_sessions")
    op.drop_table("telegram_support_sessions")

    op.drop_index("ix_support_tickets_created_at", table_name="support_tickets")
    op.drop_index("ix_support_tickets_status", table_name="support_tickets")
    op.drop_index("ix_support_tickets_telegram_chat_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_phone", table_name="support_tickets")
    op.drop_index("ix_support_tickets_user_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_source", table_name="support_tickets")
    op.drop_table("support_tickets")
