"""add passenger request seat composition

Revision ID: 0015_request_seat_mix
Revises: 0014_ticket_messages
Create Date: 2026-03-07
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0015_request_seat_mix"
down_revision: Union[str, None] = "0014_ticket_messages"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "passenger_requests",
        sa.Column("male_seats", sa.Integer(), nullable=False, server_default="0"),
    )
    op.add_column(
        "passenger_requests",
        sa.Column("female_seats", sa.Integer(), nullable=False, server_default="0"),
    )

    op.execute(
        """
        UPDATE passenger_requests pr
        SET male_seats = CASE WHEN u.gender = 'male' THEN pr.seats_needed ELSE 0 END,
            female_seats = CASE WHEN u.gender = 'female' THEN pr.seats_needed ELSE 0 END
        FROM users u
        WHERE u.id = pr.passenger_id
        """
    )

    op.alter_column("passenger_requests", "male_seats", server_default=None)
    op.alter_column("passenger_requests", "female_seats", server_default=None)


def downgrade() -> None:
    op.drop_column("passenger_requests", "female_seats")
    op.drop_column("passenger_requests", "male_seats")
