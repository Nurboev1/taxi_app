"""add admin credentials table

Revision ID: 0010_admin_credentials
Revises: 0009_user_password_hash
Create Date: 2026-03-07
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0010_admin_credentials"
down_revision: Union[str, None] = "0009_user_password_hash"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "admin_credentials",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("username", sa.String(length=100), nullable=False),
        sa.Column("password_hash", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("username", name="uq_admin_credentials_username"),
    )
    op.create_index(
        "ix_admin_credentials_username",
        "admin_credentials",
        ["username"],
        unique=True,
    )


def downgrade() -> None:
    op.drop_index("ix_admin_credentials_username", table_name="admin_credentials")
    op.drop_table("admin_credentials")
