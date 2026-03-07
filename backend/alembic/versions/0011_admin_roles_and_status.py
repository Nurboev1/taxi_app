"""add admin role fields

Revision ID: 0011_admin_roles_and_status
Revises: 0010_admin_credentials
Create Date: 2026-03-07
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0011_admin_roles_and_status"
down_revision: Union[str, None] = "0010_admin_credentials"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column(
        "admin_credentials",
        sa.Column(
            "role",
            sa.String(length=20),
            nullable=False,
            server_default="superadmin",
        ),
    )
    op.add_column(
        "admin_credentials",
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
    )
    op.add_column(
        "admin_credentials",
        sa.Column("created_by", sa.String(length=100), nullable=True),
    )
    op.create_index(
        "ix_admin_credentials_role",
        "admin_credentials",
        ["role"],
        unique=False,
    )
    op.alter_column("admin_credentials", "role", server_default=None)
    op.alter_column("admin_credentials", "is_active", server_default=None)


def downgrade() -> None:
    op.drop_index("ix_admin_credentials_role", table_name="admin_credentials")
    op.drop_column("admin_credentials", "created_by")
    op.drop_column("admin_credentials", "is_active")
    op.drop_column("admin_credentials", "role")
