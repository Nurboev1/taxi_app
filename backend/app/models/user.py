from datetime import datetime, timezone

from sqlalchemy import Boolean, DateTime, Enum, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.session import Base
from app.models.enums import AppLanguage, Gender, UserRole


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    phone: Mapped[str] = mapped_column(String(32), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100), default="Foydalanuvchi")
    first_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    last_name: Mapped[str | None] = mapped_column(String(100), nullable=True)
    car_model: Mapped[str | None] = mapped_column(String(100), nullable=True)
    car_number: Mapped[str | None] = mapped_column(String(32), nullable=True)
    gender: Mapped[Gender | None] = mapped_column(Enum(Gender), nullable=True)
    age: Mapped[int | None] = mapped_column(Integer, nullable=True)
    language: Mapped[AppLanguage] = mapped_column(Enum(AppLanguage), default=AppLanguage.uz)
    phone_visible: Mapped[bool] = mapped_column(Boolean, default=True)
    driver_blocked: Mapped[bool] = mapped_column(Boolean, default=False)
    driver_access_override: Mapped[bool] = mapped_column(Boolean, default=False)
    driver_block_reason: Mapped[str | None] = mapped_column(String(255), nullable=True)
    driver_unblocked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), default=UserRole.none)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
