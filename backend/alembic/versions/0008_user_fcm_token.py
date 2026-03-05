"""add user fcm token

Revision ID: 0008_user_fcm_token
Revises: 0007_driver_unblocked_at
Create Date: 2026-03-03
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0008_user_fcm_token"
down_revision: Union[str, None] = "0007_driver_unblocked_at"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("users", sa.Column("fcm_token", sa.String(length=512), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "fcm_token")

