"""add support ticket messages and activity fields

Revision ID: 0014_ticket_messages
Revises: 0013_support_tickets
Create Date: 2026-03-07
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0014_ticket_messages"
down_revision: Union[str, None] = "0013_support_tickets"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("support_tickets", sa.Column("last_actor", sa.String(length=24), nullable=True))
    op.add_column("support_tickets", sa.Column("last_activity_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("support_tickets", sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True))

    op.execute("UPDATE support_tickets SET last_actor='user' WHERE last_actor IS NULL")
    op.execute("UPDATE support_tickets SET last_activity_at=created_at WHERE last_activity_at IS NULL")

    op.alter_column("support_tickets", "last_actor", nullable=False)
    op.alter_column("support_tickets", "last_activity_at", nullable=False)

    op.create_index("ix_support_tickets_last_actor", "support_tickets", ["last_actor"], unique=False)
    op.create_index(
        "ix_support_tickets_last_activity_at",
        "support_tickets",
        ["last_activity_at"],
        unique=False,
    )
    op.create_index("ix_support_tickets_closed_at", "support_tickets", ["closed_at"], unique=False)
    op.create_index("ix_support_tickets_updated_at", "support_tickets", ["updated_at"], unique=False)

    op.create_table(
        "support_ticket_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("ticket_id", sa.Integer(), sa.ForeignKey("support_tickets.id"), nullable=False),
        sa.Column("sender_role", sa.String(length=24), nullable=False),
        sa.Column("message", sa.Text(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index(
        "ix_support_ticket_messages_ticket_id",
        "support_ticket_messages",
        ["ticket_id"],
        unique=False,
    )
    op.create_index(
        "ix_support_ticket_messages_sender_role",
        "support_ticket_messages",
        ["sender_role"],
        unique=False,
    )
    op.create_index(
        "ix_support_ticket_messages_created_at",
        "support_ticket_messages",
        ["created_at"],
        unique=False,
    )

    op.execute(
        """
        INSERT INTO support_ticket_messages (ticket_id, sender_role, message, created_at)
        SELECT id, 'user', message, created_at
        FROM support_tickets
        WHERE message IS NOT NULL AND length(trim(message)) > 0
        """
    )


def downgrade() -> None:
    op.drop_index("ix_support_ticket_messages_created_at", table_name="support_ticket_messages")
    op.drop_index("ix_support_ticket_messages_sender_role", table_name="support_ticket_messages")
    op.drop_index("ix_support_ticket_messages_ticket_id", table_name="support_ticket_messages")
    op.drop_table("support_ticket_messages")

    op.drop_index("ix_support_tickets_updated_at", table_name="support_tickets")
    op.drop_index("ix_support_tickets_closed_at", table_name="support_tickets")
    op.drop_index("ix_support_tickets_last_activity_at", table_name="support_tickets")
    op.drop_index("ix_support_tickets_last_actor", table_name="support_tickets")
    op.drop_column("support_tickets", "closed_at")
    op.drop_column("support_tickets", "last_activity_at")
    op.drop_column("support_tickets", "last_actor")
