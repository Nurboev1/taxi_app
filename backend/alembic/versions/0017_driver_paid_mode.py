"""add driver monetization tables

Revision ID: 0017_driver_paid_mode
Revises: 0016_admin_audit_log_metadata
Create Date: 2026-03-13
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "0017_driver_paid_mode"
down_revision: Union[str, None] = "0016_admin_audit_log_metadata"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "monetization_settings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("driver_paid_mode_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("driver_monthly_price", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("click_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("payme_enabled", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("updated_by", sa.String(length=100), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "driver_subscriptions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("remaining_seconds", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="inactive"),
        sa.Column("countdown_started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_payment_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_payment_amount", sa.Integer(), nullable=True),
        sa.Column("last_payment_provider", sa.String(length=24), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_driver_subscriptions_user_id", "driver_subscriptions", ["user_id"], unique=True)
    op.create_index("ix_driver_subscriptions_status", "driver_subscriptions", ["status"], unique=False)
    op.create_index(
        "ix_driver_subscriptions_countdown_started_at",
        "driver_subscriptions",
        ["countdown_started_at"],
        unique=False,
    )
    op.create_index("ix_driver_subscriptions_created_at", "driver_subscriptions", ["created_at"], unique=False)
    op.create_index("ix_driver_subscriptions_updated_at", "driver_subscriptions", ["updated_at"], unique=False)
    op.create_index("ix_driver_subscriptions_last_payment_at", "driver_subscriptions", ["last_payment_at"], unique=False)

    op.create_table(
        "driver_payments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), nullable=False),
        sa.Column("provider", sa.String(length=24), nullable=False),
        sa.Column("amount", sa.Integer(), nullable=False),
        sa.Column("months_count", sa.Integer(), nullable=False, server_default="1"),
        sa.Column("status", sa.String(length=24), nullable=False, server_default="pending"),
        sa.Column("external_id", sa.String(length=128), nullable=True),
        sa.Column("checkout_url", sa.String(length=1024), nullable=True),
        sa.Column("note", sa.String(length=255), nullable=True),
        sa.Column("raw_payload", sa.Text(), nullable=True),
        sa.Column("paid_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False),
        sa.ForeignKeyConstraint(["user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_driver_payments_user_id", "driver_payments", ["user_id"], unique=False)
    op.create_index("ix_driver_payments_provider", "driver_payments", ["provider"], unique=False)
    op.create_index("ix_driver_payments_status", "driver_payments", ["status"], unique=False)
    op.create_index("ix_driver_payments_external_id", "driver_payments", ["external_id"], unique=False)
    op.create_index("ix_driver_payments_paid_at", "driver_payments", ["paid_at"], unique=False)
    op.create_index("ix_driver_payments_created_at", "driver_payments", ["created_at"], unique=False)
    op.create_index("ix_driver_payments_updated_at", "driver_payments", ["updated_at"], unique=False)

    op.execute(
        """
        INSERT INTO monetization_settings
            (id, driver_paid_mode_enabled, driver_monthly_price, click_enabled, payme_enabled, updated_by, created_at, updated_at)
        VALUES
            (1, false, 0, false, false, 'migration', now(), now())
        """
    )


def downgrade() -> None:
    op.drop_index("ix_driver_payments_updated_at", table_name="driver_payments")
    op.drop_index("ix_driver_payments_created_at", table_name="driver_payments")
    op.drop_index("ix_driver_payments_paid_at", table_name="driver_payments")
    op.drop_index("ix_driver_payments_external_id", table_name="driver_payments")
    op.drop_index("ix_driver_payments_status", table_name="driver_payments")
    op.drop_index("ix_driver_payments_provider", table_name="driver_payments")
    op.drop_index("ix_driver_payments_user_id", table_name="driver_payments")
    op.drop_table("driver_payments")

    op.drop_index("ix_driver_subscriptions_last_payment_at", table_name="driver_subscriptions")
    op.drop_index("ix_driver_subscriptions_updated_at", table_name="driver_subscriptions")
    op.drop_index("ix_driver_subscriptions_created_at", table_name="driver_subscriptions")
    op.drop_index("ix_driver_subscriptions_countdown_started_at", table_name="driver_subscriptions")
    op.drop_index("ix_driver_subscriptions_status", table_name="driver_subscriptions")
    op.drop_index("ix_driver_subscriptions_user_id", table_name="driver_subscriptions")
    op.drop_table("driver_subscriptions")

    op.drop_table("monetization_settings")
