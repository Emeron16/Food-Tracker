from sqlalchemy import String, Boolean, DateTime, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from typing import Optional
from datetime import datetime
import uuid

from app.db.database import Base


class User(Base):
    """User model for authentication and preferences."""

    __tablename__ = "users"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    hashed_password: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Profile
    full_name: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    household_size: Mapped[int] = mapped_column(Integer, default=2)
    cooking_skill_level: Mapped[int] = mapped_column(Integer, default=3)  # 1-5

    # Preferences (stored as JSON strings)
    dietary_restrictions: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    allergies: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    preferred_cuisines: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    preferred_meal_times: Mapped[Optional[str]] = mapped_column(Text, nullable=True)

    # Apple Sign In
    apple_user_id: Mapped[Optional[str]] = mapped_column(
        String(255),
        unique=True,
        nullable=True,
        index=True
    )

    # Account status
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False)

    # Notification preferences
    notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    expiration_warning_days: Mapped[int] = mapped_column(Integer, default=3)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now()
    )
    last_login_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    # Relationships
    grocery_items: Mapped[list["GroceryItem"]] = relationship(
        "GroceryItem",
        back_populates="user",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<User {self.email}>"
