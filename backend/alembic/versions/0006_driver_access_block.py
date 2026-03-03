"""add driver access block fields

Revision ID: 0006_driver_access_block
Revises: 0005_user_notifications
Create Date: 2026-02-28 08:10:00
"""

from alembic import op
import sqlalchemy as sa


revision = "0006_driver_access_block"
down_revision = "0005_user_notifications"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("driver_blocked", sa.Boolean(), nullable=False, server_default=sa.text("false")))
    op.add_column(
        "users",
        sa.Column("driver_access_override", sa.Boolean(), nullable=False, server_default=sa.text("false")),
    )
    op.add_column("users", sa.Column("driver_block_reason", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "driver_block_reason")
    op.drop_column("users", "driver_access_override")
    op.drop_column("users", "driver_blocked")
