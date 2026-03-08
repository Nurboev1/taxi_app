"""initial tables

Revision ID: 0001_initial
Revises:
Create Date: 2026-02-25 19:50:00
"""

from alembic import op
import sqlalchemy as sa


revision = "0001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    user_role = sa.Enum("none", "driver", "passenger", name="userrole")
    trip_status = sa.Enum("open", "full", "cancelled", "done", name="tripstatus")
    req_status = sa.Enum("open", "locked", "chosen", "cancelled", "expired", name="requeststatus")
    claim_status = sa.Enum("pending", "accepted", "rejected", name="claimstatus")

    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("phone", sa.String(length=32), nullable=False, unique=True),
        sa.Column("name", sa.String(length=100), nullable=False),
        sa.Column("role", user_role, nullable=False, server_default="none"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_users_phone", "users", ["phone"], unique=True)

    op.create_table(
        "otp_codes",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("phone", sa.String(length=32), nullable=False),
        sa.Column("code", sa.String(length=8), nullable=False),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_otp_codes_phone", "otp_codes", ["phone"], unique=False)

    op.create_table(
        "driver_trips",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("from_location", sa.String(length=120), nullable=False),
        sa.Column("to_location", sa.String(length=120), nullable=False),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("seats_total", sa.Integer(), nullable=False, server_default="4"),
        sa.Column("seats_taken", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("price_per_seat", sa.Numeric(12, 2), nullable=False),
        sa.Column("status", trip_status, nullable=False, server_default="open"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_driver_trips_driver_id", "driver_trips", ["driver_id"], unique=False)
    op.create_index("ix_driver_trips_from_location", "driver_trips", ["from_location"], unique=False)
    op.create_index("ix_driver_trips_to_location", "driver_trips", ["to_location"], unique=False)
    op.create_index("ix_driver_trips_start_time", "driver_trips", ["start_time"], unique=False)
    op.create_index("ix_driver_trips_end_time", "driver_trips", ["end_time"], unique=False)
    op.create_index("ix_driver_trips_status", "driver_trips", ["status"], unique=False)

    op.create_table(
        "passenger_requests",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("passenger_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("from_location", sa.String(length=120), nullable=False),
        sa.Column("to_location", sa.String(length=120), nullable=False),
        sa.Column("start_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_time", sa.DateTime(timezone=True), nullable=False),
        sa.Column("seats_needed", sa.Integer(), nullable=False),
        sa.Column("status", req_status, nullable=False, server_default="open"),
        sa.Column("chosen_claim_id", sa.Integer(), nullable=True),
        sa.Column("chosen_driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_passenger_requests_passenger_id", "passenger_requests", ["passenger_id"], unique=False)
    op.create_index("ix_passenger_requests_from_location", "passenger_requests", ["from_location"], unique=False)
    op.create_index("ix_passenger_requests_to_location", "passenger_requests", ["to_location"], unique=False)
    op.create_index("ix_passenger_requests_start_time", "passenger_requests", ["start_time"], unique=False)
    op.create_index("ix_passenger_requests_end_time", "passenger_requests", ["end_time"], unique=False)
    op.create_index("ix_passenger_requests_status", "passenger_requests", ["status"], unique=False)

    op.create_table(
        "request_claims",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("request_id", sa.Integer(), sa.ForeignKey("passenger_requests.id"), nullable=False),
        sa.Column("driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("trip_id", sa.Integer(), sa.ForeignKey("driver_trips.id"), nullable=False),
        sa.Column("status", claim_status, nullable=False, server_default="pending"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("request_id", "driver_id", name="uq_request_driver_claim"),
    )
    op.create_index("ix_request_claims_request_id", "request_claims", ["request_id"], unique=False)
    op.create_index("ix_request_claims_driver_id", "request_claims", ["driver_id"], unique=False)
    op.create_index("ix_request_claims_trip_id", "request_claims", ["trip_id"], unique=False)
    op.create_index("ix_request_claims_status", "request_claims", ["status"], unique=False)

    op.create_foreign_key(
        "fk_passenger_requests_chosen_claim",
        "passenger_requests",
        "request_claims",
        ["chosen_claim_id"],
        ["id"],
    )

    op.create_table(
        "chats",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("request_id", sa.Integer(), sa.ForeignKey("passenger_requests.id"), nullable=False),
        sa.Column("passenger_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("driver_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("request_id", "passenger_id", "driver_id", name="uq_chat_triplet"),
    )
    op.create_index("ix_chats_request_id", "chats", ["request_id"], unique=False)
    op.create_index("ix_chats_passenger_id", "chats", ["passenger_id"], unique=False)
    op.create_index("ix_chats_driver_id", "chats", ["driver_id"], unique=False)

    op.create_table(
        "chat_messages",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("chat_id", sa.Integer(), sa.ForeignKey("chats.id"), nullable=False),
        sa.Column("sender_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=False),
        sa.Column("body", sa.String(length=2000), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False),
    )
    op.create_index("ix_chat_messages_chat_id", "chat_messages", ["chat_id"], unique=False)
    op.create_index("ix_chat_messages_sender_id", "chat_messages", ["sender_id"], unique=False)
    op.create_index("ix_chat_messages_created_at", "chat_messages", ["created_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_chat_messages_created_at", table_name="chat_messages")
    op.drop_index("ix_chat_messages_sender_id", table_name="chat_messages")
    op.drop_index("ix_chat_messages_chat_id", table_name="chat_messages")
    op.drop_table("chat_messages")

    op.drop_index("ix_chats_driver_id", table_name="chats")
    op.drop_index("ix_chats_passenger_id", table_name="chats")
    op.drop_index("ix_chats_request_id", table_name="chats")
    op.drop_table("chats")

    op.drop_constraint("fk_passenger_requests_chosen_claim", "passenger_requests", type_="foreignkey")

    op.drop_index("ix_request_claims_status", table_name="request_claims")
    op.drop_index("ix_request_claims_trip_id", table_name="request_claims")
    op.drop_index("ix_request_claims_driver_id", table_name="request_claims")
    op.drop_index("ix_request_claims_request_id", table_name="request_claims")
    op.drop_table("request_claims")

    op.drop_index("ix_passenger_requests_status", table_name="passenger_requests")
    op.drop_index("ix_passenger_requests_end_time", table_name="passenger_requests")
    op.drop_index("ix_passenger_requests_start_time", table_name="passenger_requests")
    op.drop_index("ix_passenger_requests_to_location", table_name="passenger_requests")
    op.drop_index("ix_passenger_requests_from_location", table_name="passenger_requests")
    op.drop_index("ix_passenger_requests_passenger_id", table_name="passenger_requests")
    op.drop_table("passenger_requests")

    op.drop_index("ix_driver_trips_status", table_name="driver_trips")
    op.drop_index("ix_driver_trips_end_time", table_name="driver_trips")
    op.drop_index("ix_driver_trips_start_time", table_name="driver_trips")
    op.drop_index("ix_driver_trips_to_location", table_name="driver_trips")
    op.drop_index("ix_driver_trips_from_location", table_name="driver_trips")
    op.drop_index("ix_driver_trips_driver_id", table_name="driver_trips")
    op.drop_table("driver_trips")

    op.drop_index("ix_otp_codes_phone", table_name="otp_codes")
    op.drop_table("otp_codes")

    op.drop_index("ix_users_phone", table_name="users")
    op.drop_table("users")

    sa.Enum(name="claimstatus").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="requeststatus").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="tripstatus").drop(op.get_bind(), checkfirst=True)
    sa.Enum(name="userrole").drop(op.get_bind(), checkfirst=True)
