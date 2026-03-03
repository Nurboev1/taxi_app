"""add trip ratings

Revision ID: 0003_trip_ratings
Revises: 0002_profile_and_prefs
Create Date: 2026-02-26 20:25:00
"""

from alembic import op
import sqlalchemy as sa


revision = "0003_trip_ratings"
down_revision = "0002_profile_and_prefs"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trip_ratings",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("trip_id", sa.Integer(), sa.ForeignKey("driver_trips.id"), nullable=False),
        sa.Column("passenger_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("stars", sa.Integer(), nullable=False),
        sa.Column("comment", sa.String(length=500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint("trip_id", "passenger_id", name="uq_trip_passenger_rating"),
    )
    op.create_index("ix_trip_ratings_trip_id", "trip_ratings", ["trip_id"], unique=False)
    op.create_index("ix_trip_ratings_passenger_id", "trip_ratings", ["passenger_id"], unique=False)
    op.create_index("ix_trip_ratings_driver_id", "trip_ratings", ["driver_id"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_trip_ratings_driver_id", table_name="trip_ratings")
    op.drop_index("ix_trip_ratings_passenger_id", table_name="trip_ratings")
    op.drop_index("ix_trip_ratings_trip_id", table_name="trip_ratings")
    op.drop_table("trip_ratings")
