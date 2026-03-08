"""add support ticket context and media metadata

Revision ID: 0017_support_ticket_ctx_media
Revises: 0016_admin_audit_log_metadata
Create Date: 2026-03-08
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0017_support_ticket_ctx_media"
down_revision: Union[str, None] = "0016_admin_audit_log_metadata"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("support_tickets", sa.Column("context_trip_id", sa.Integer(), nullable=True))
    op.add_column("support_tickets", sa.Column("context_request_id", sa.Integer(), nullable=True))
    op.add_column("support_tickets", sa.Column("context_claim_id", sa.Integer(), nullable=True))
    op.add_column("support_tickets", sa.Column("context_summary", sa.Text(), nullable=True))
    op.add_column("support_tickets", sa.Column("context_refreshed_at", sa.DateTime(timezone=True), nullable=True))

    op.create_index("ix_support_tickets_context_trip_id", "support_tickets", ["context_trip_id"], unique=False)
    op.create_index("ix_support_tickets_context_request_id", "support_tickets", ["context_request_id"], unique=False)
    op.create_index("ix_support_tickets_context_claim_id", "support_tickets", ["context_claim_id"], unique=False)
    op.create_index(
        "ix_support_tickets_context_refreshed_at",
        "support_tickets",
        ["context_refreshed_at"],
        unique=False,
    )

    op.add_column("support_ticket_messages", sa.Column("message_kind", sa.String(length=24), nullable=True))
    op.add_column("support_ticket_messages", sa.Column("telegram_message_id", sa.Integer(), nullable=True))
    op.add_column("support_ticket_messages", sa.Column("media_file_id", sa.String(length=256), nullable=True))
    op.add_column("support_ticket_messages", sa.Column("media_file_unique_id", sa.String(length=256), nullable=True))
    op.add_column("support_ticket_messages", sa.Column("media_mime_type", sa.String(length=128), nullable=True))
    op.add_column("support_ticket_messages", sa.Column("media_file_size", sa.Integer(), nullable=True))
    op.add_column("support_ticket_messages", sa.Column("media_caption", sa.Text(), nullable=True))

    op.execute("UPDATE support_ticket_messages SET message_kind='text' WHERE message_kind IS NULL")
    op.alter_column("support_ticket_messages", "message_kind", nullable=False)

    op.create_index("ix_support_ticket_messages_message_kind", "support_ticket_messages", ["message_kind"], unique=False)
    op.create_index(
        "ix_support_ticket_messages_telegram_message_id",
        "support_ticket_messages",
        ["telegram_message_id"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_support_ticket_messages_telegram_message_id", table_name="support_ticket_messages")
    op.drop_index("ix_support_ticket_messages_message_kind", table_name="support_ticket_messages")

    op.drop_column("support_ticket_messages", "media_caption")
    op.drop_column("support_ticket_messages", "media_file_size")
    op.drop_column("support_ticket_messages", "media_mime_type")
    op.drop_column("support_ticket_messages", "media_file_unique_id")
    op.drop_column("support_ticket_messages", "media_file_id")
    op.drop_column("support_ticket_messages", "telegram_message_id")
    op.drop_column("support_ticket_messages", "message_kind")

    op.drop_index("ix_support_tickets_context_refreshed_at", table_name="support_tickets")
    op.drop_index("ix_support_tickets_context_claim_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_context_request_id", table_name="support_tickets")
    op.drop_index("ix_support_tickets_context_trip_id", table_name="support_tickets")

    op.drop_column("support_tickets", "context_refreshed_at")
    op.drop_column("support_tickets", "context_summary")
    op.drop_column("support_tickets", "context_claim_id")
    op.drop_column("support_tickets", "context_request_id")
    op.drop_column("support_tickets", "context_trip_id")
