"""add completed claim status

Revision ID: 0004_claim_completed
Revises: 0003_trip_ratings
Create Date: 2026-02-26 21:05:00
"""

from alembic import op


revision = "0004_claim_completed"
down_revision = "0003_trip_ratings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.execute("ALTER TYPE claimstatus ADD VALUE IF NOT EXISTS 'completed'")


def downgrade() -> None:
    # PostgreSQL enum value removal is unsafe in downgrade; keep no-op.
    pass
