"""add driver_unblocked_at timestamp

Revision ID: 0007_driver_unblocked_at
Revises: 0006_driver_access_block
Create Date: 2026-02-28 00:00:00.000000
"""

from alembic import op
import sqlalchemy as sa


revision = "0007_driver_unblocked_at"
down_revision = "0006_driver_access_block"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("users", sa.Column("driver_unblocked_at", sa.DateTime(timezone=True), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "driver_unblocked_at")
