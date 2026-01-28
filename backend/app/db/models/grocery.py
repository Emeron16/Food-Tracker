from sqlalchemy import String, Float, Boolean, DateTime, Text, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy.sql import func
from typing import Optional, TYPE_CHECKING
from datetime import datetime
import uuid

from app.db.database import Base

if TYPE_CHECKING:
    from app.db.models.user import User


class GroceryItem(Base):
    """Grocery item model for tracking food in user's pantry."""

    __tablename__ = "grocery_items"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )

    # Foreign key to user
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True
    )

    # Basic info
    name: Mapped[str] = mapped_column(String(255))
    category: Mapped[str] = mapped_column(String(50), index=True)
    storage_location: Mapped[str] = mapped_column(String(50))

    # Quantity
    quantity: Mapped[float] = mapped_column(Float, default=1.0)
    unit: Mapped[str] = mapped_column(String(20), default="piece")

    # Dates
    purchase_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    expiration_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )
    predicted_expiration_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

    # ML prediction metadata
    confidence_score: Mapped[Optional[float]] = mapped_column(Float, nullable=True)

    # Barcode and external IDs
    barcode: Mapped[Optional[str]] = mapped_column(String(50), nullable=True, index=True)
    external_product_id: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)

    # Additional info
    notes: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    image_url: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)

    # Consumption tracking
    is_consumed: Mapped[bool] = mapped_column(Boolean, default=False)
    consumed_date: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True),
        nullable=True
    )

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

    # Relationships
    user: Mapped["User"] = relationship("User", back_populates="grocery_items")
    consumption_records: Mapped[list["ConsumptionRecord"]] = relationship(
        "ConsumptionRecord",
        back_populates="grocery_item",
        cascade="all, delete-orphan"
    )

    def __repr__(self) -> str:
        return f"<GroceryItem {self.name} ({self.category})>"


class ConsumptionRecord(Base):
    """Tracks consumption/waste events for ML training data."""

    __tablename__ = "consumption_records"

    id: Mapped[str] = mapped_column(
        String(36),
        primary_key=True,
        default=lambda: str(uuid.uuid4())
    )

    # Foreign key to grocery item
    grocery_item_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey("grocery_items.id", ondelete="CASCADE"),
        index=True
    )

    # Consumption details
    consumed_date: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    quantity_consumed: Mapped[float] = mapped_column(Float)

    # Waste tracking
    was_expired: Mapped[bool] = mapped_column(Boolean, default=False)
    wasted_quantity: Mapped[float] = mapped_column(Float, default=0.0)

    # For ML training
    actual_shelf_life_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    predicted_shelf_life_days: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Timestamps
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now()
    )

    # Relationships
    grocery_item: Mapped["GroceryItem"] = relationship(
        "GroceryItem",
        back_populates="consumption_records"
    )

    def __repr__(self) -> str:
        return f"<ConsumptionRecord {self.grocery_item_id} - {self.consumed_date}>"
