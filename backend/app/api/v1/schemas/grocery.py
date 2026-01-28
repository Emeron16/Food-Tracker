from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime
from enum import Enum


class FoodCategory(str, Enum):
    DAIRY = "Dairy"
    MEAT = "Meat"
    SEAFOOD = "Seafood"
    PRODUCE = "Produce"
    BAKERY = "Bakery"
    FROZEN = "Frozen"
    PANTRY = "Pantry"
    BEVERAGES = "Beverages"
    CONDIMENTS = "Condiments"
    SNACKS = "Snacks"
    OTHER = "Other"


class StorageLocation(str, Enum):
    REFRIGERATOR = "Refrigerator"
    FREEZER = "Freezer"
    PANTRY = "Pantry"
    COUNTER = "Counter"


class GroceryItemBase(BaseModel):
    """Base schema for grocery items."""
    name: str = Field(..., min_length=1, max_length=255)
    category: FoodCategory
    storage_location: StorageLocation
    quantity: float = Field(default=1.0, gt=0)
    unit: str = Field(default="piece", max_length=20)
    purchase_date: datetime
    expiration_date: Optional[datetime] = None
    predicted_expiration_date: Optional[datetime] = None
    confidence_score: Optional[float] = Field(None, ge=0, le=1)
    barcode: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = None


class GroceryItemCreate(GroceryItemBase):
    """Schema for creating a grocery item."""
    id: Optional[str] = None  # Client can provide UUID for sync


class GroceryItemUpdate(BaseModel):
    """Schema for updating a grocery item."""
    name: Optional[str] = Field(None, min_length=1, max_length=255)
    category: Optional[FoodCategory] = None
    storage_location: Optional[StorageLocation] = None
    quantity: Optional[float] = Field(None, gt=0)
    unit: Optional[str] = Field(None, max_length=20)
    purchase_date: Optional[datetime] = None
    expiration_date: Optional[datetime] = None
    predicted_expiration_date: Optional[datetime] = None
    confidence_score: Optional[float] = Field(None, ge=0, le=1)
    barcode: Optional[str] = Field(None, max_length=50)
    notes: Optional[str] = None
    is_consumed: Optional[bool] = None
    consumed_date: Optional[datetime] = None


class GroceryItemResponse(GroceryItemBase):
    """Schema for grocery item response."""
    id: str
    user_id: str
    is_consumed: bool
    consumed_date: Optional[datetime] = None
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class GrocerySyncRequest(BaseModel):
    """Schema for syncing groceries from iOS app."""
    items: list[GroceryItemCreate]
    deleted_ids: list[str] = []  # IDs of items deleted on client
    last_sync_at: Optional[datetime] = None


class GrocerySyncResponse(BaseModel):
    """Schema for sync response."""
    items: list[GroceryItemResponse]
    deleted_ids: list[str]  # IDs deleted on server
    sync_timestamp: datetime


class ConsumptionRecordCreate(BaseModel):
    """Schema for recording consumption/waste."""
    grocery_item_id: str
    consumed_date: datetime
    quantity_consumed: float
    was_expired: bool = False
    wasted_quantity: float = 0.0
    actual_shelf_life_days: Optional[int] = None


class ConsumptionRecordResponse(BaseModel):
    """Schema for consumption record response."""
    id: str
    grocery_item_id: str
    consumed_date: datetime
    quantity_consumed: float
    was_expired: bool
    wasted_quantity: float
    actual_shelf_life_days: Optional[int] = None
    predicted_shelf_life_days: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True
