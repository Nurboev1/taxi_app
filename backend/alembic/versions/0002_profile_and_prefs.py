"""add user profile and request preferred time

Revision ID: 0002_profile_and_prefs
Revises: 0001_initial
Create Date: 2026-02-26 18:40:00
"""

from alembic import op
import sqlalchemy as sa


revision = "0002_profile_and_prefs"
down_revision = "0001_initial"
branch_labels = None
depends_on = None


def upgrade() -> None:
    gender = sa.Enum("male", "female", name="gender")
    app_language = sa.Enum("uz", "ru", "en", name="applanguage")
    bind = op.get_bind()
    gender.create(bind, checkfirst=True)
    app_language.create(bind, checkfirst=True)

    op.add_column("users", sa.Column("first_name", sa.String(length=100), nullable=True))
    op.add_column("users", sa.Column("last_name", sa.String(length=100), nullable=True))
    op.add_column("users", sa.Column("car_model", sa.String(length=100), nullable=True))
    op.add_column("users", sa.Column("car_number", sa.String(length=32), nullable=True))
    op.add_column("users", sa.Column("gender", gender, nullable=True))
    op.add_column("users", sa.Column("age", sa.Integer(), nullable=True))
    op.add_column("users", sa.Column("language", app_language, nullable=False, server_default="uz"))
    op.add_column("users", sa.Column("phone_visible", sa.Boolean(), nullable=False, server_default=sa.text("true")))

    op.add_column("passenger_requests", sa.Column("preferred_time", sa.DateTime(timezone=True), nullable=True))
    op.create_index("ix_passenger_requests_preferred_time", "passenger_requests", ["preferred_time"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_passenger_requests_preferred_time", table_name="passenger_requests")
    op.drop_column("passenger_requests", "preferred_time")

    op.drop_column("users", "phone_visible")
    op.drop_column("users", "language")
    op.drop_column("users", "age")
    op.drop_column("users", "gender")
    op.drop_column("users", "car_number")
    op.drop_column("users", "car_model")
    op.drop_column("users", "last_name")
    op.drop_column("users", "first_name")

    sa.Enum(name="applanguage").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="gender").drop(op.get_bind(), checkfirst=True)
