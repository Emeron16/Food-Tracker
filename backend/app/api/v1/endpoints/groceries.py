from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, delete
from datetime import datetime, timezone
from typing import Optional
import uuid

from app.db import get_db
from app.db.models import User, GroceryItem
from app.api.v1.schemas.grocery import (
    GroceryItemCreate,
    GroceryItemUpdate,
    GroceryItemResponse,
    GrocerySyncRequest,
    GrocerySyncResponse,
)

router = APIRouter(prefix="/groceries", tags=["groceries"])


# Temporary mock authentication for development
async def get_current_user_mock(db: AsyncSession = Depends(get_db)) -> User:
    """Mock authentication - returns first user or creates one."""
    result = await db.execute(select(User).limit(1))
    user = result.scalar_one_or_none()

    if not user:
        # Create a test user
        user = User(
            email="test@example.com",
            hashed_password="mock",
            full_name="Test User"
        )
        db.add(user)
        await db.commit()
        await db.refresh(user)

    return user


def grocery_to_response(item: GroceryItem) -> GroceryItemResponse:
    """Convert GroceryItem model to response schema."""
    return GroceryItemResponse(
        id=item.id,
        user_id=item.user_id,
        name=item.name,
        category=item.category,
        storage_location=item.storage_location,
        quantity=item.quantity,
        unit=item.unit,
        purchase_date=item.purchase_date,
        expiration_date=item.expiration_date,
        predicted_expiration_date=item.predicted_expiration_date,
        confidence_score=item.confidence_score,
        barcode=item.barcode,
        notes=item.notes,
        is_consumed=item.is_consumed,
        consumed_date=item.consumed_date,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.get("", response_model=list[GroceryItemResponse])
async def get_groceries(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
    category: Optional[str] = Query(None, description="Filter by category"),
    storage_location: Optional[str] = Query(None, description="Filter by storage location"),
    include_consumed: bool = Query(False, description="Include consumed items"),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
):
    """
    Get all grocery items for the current user.
    """
    query = select(GroceryItem).where(GroceryItem.user_id == current_user.id)

    if not include_consumed:
        query = query.where(GroceryItem.is_consumed == False)

    if category:
        query = query.where(GroceryItem.category == category)

    if storage_location:
        query = query.where(GroceryItem.storage_location == storage_location)

    query = query.order_by(GroceryItem.purchase_date.desc()).offset(skip).limit(limit)

    result = await db.execute(query)
    items = result.scalars().all()

    return [grocery_to_response(item) for item in items]


@router.post("", response_model=GroceryItemResponse, status_code=status.HTTP_201_CREATED)
async def create_grocery(
    item_data: GroceryItemCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
):
    """
    Create a new grocery item.
    """
    item = GroceryItem(
        id=item_data.id or str(uuid.uuid4()),
        user_id=current_user.id,
        name=item_data.name,
        category=item_data.category.value,
        storage_location=item_data.storage_location.value,
        quantity=item_data.quantity,
        unit=item_data.unit,
        purchase_date=item_data.purchase_date,
        expiration_date=item_data.expiration_date,
        predicted_expiration_date=item_data.predicted_expiration_date,
        confidence_score=item_data.confidence_score,
        barcode=item_data.barcode,
        notes=item_data.notes,
    )

    db.add(item)
    await db.commit()
    await db.refresh(item)

    return grocery_to_response(item)


@router.get("/{item_id}", response_model=GroceryItemResponse)
async def get_grocery(
    item_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
):
    """
    Get a specific grocery item.
    """
    result = await db.execute(
        select(GroceryItem).where(
            GroceryItem.id == item_id,
            GroceryItem.user_id == current_user.id
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grocery item not found"
        )

    return grocery_to_response(item)


@router.patch("/{item_id}", response_model=GroceryItemResponse)
async def update_grocery(
    item_id: str,
    item_data: GroceryItemUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
):
    """
    Update a grocery item.
    """
    result = await db.execute(
        select(GroceryItem).where(
            GroceryItem.id == item_id,
            GroceryItem.user_id == current_user.id
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grocery item not found"
        )

    # Update only provided fields
    update_data = item_data.model_dump(exclude_unset=True)

    for field, value in update_data.items():
        if field == "category" and value:
            setattr(item, field, value.value)
        elif field == "storage_location" and value:
            setattr(item, field, value.value)
        else:
            setattr(item, field, value)

    await db.commit()
    await db.refresh(item)

    return grocery_to_response(item)


@router.delete("/{item_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_grocery(
    item_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
):
    """
    Delete a grocery item.
    """
    result = await db.execute(
        select(GroceryItem).where(
            GroceryItem.id == item_id,
            GroceryItem.user_id == current_user.id
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grocery item not found"
        )

    await db.delete(item)
    await db.commit()


@router.post("/{item_id}/consume", response_model=GroceryItemResponse)
async def mark_consumed(
    item_id: str,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
):
    """
    Mark a grocery item as consumed.
    """
    result = await db.execute(
        select(GroceryItem).where(
            GroceryItem.id == item_id,
            GroceryItem.user_id == current_user.id
        )
    )
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Grocery item not found"
        )

    item.is_consumed = True
    item.consumed_date = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(item)

    return grocery_to_response(item)


@router.post("/sync", response_model=GrocerySyncResponse)
async def sync_groceries(
    sync_request: GrocerySyncRequest,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user_mock),
):
    """
    Sync groceries from iOS app.
    Handles bidirectional sync with conflict resolution (last-write-wins).
    """
    sync_timestamp = datetime.now(timezone.utc)
    server_deleted_ids = []

    # Process deleted items from client
    if sync_request.deleted_ids:
        await db.execute(
            delete(GroceryItem).where(
                GroceryItem.id.in_(sync_request.deleted_ids),
                GroceryItem.user_id == current_user.id
            )
        )

    # Process items from client
    for item_data in sync_request.items:
        item_id = item_data.id or str(uuid.uuid4())

        # Check if item exists
        result = await db.execute(
            select(GroceryItem).where(
                GroceryItem.id == item_id,
                GroceryItem.user_id == current_user.id
            )
        )
        existing_item = result.scalar_one_or_none()

        if existing_item:
            # Update existing item (last-write-wins)
            existing_item.name = item_data.name
            existing_item.category = item_data.category.value
            existing_item.storage_location = item_data.storage_location.value
            existing_item.quantity = item_data.quantity
            existing_item.unit = item_data.unit
            existing_item.purchase_date = item_data.purchase_date
            existing_item.expiration_date = item_data.expiration_date
            existing_item.predicted_expiration_date = item_data.predicted_expiration_date
            existing_item.confidence_score = item_data.confidence_score
            existing_item.barcode = item_data.barcode
            existing_item.notes = item_data.notes
        else:
            # Create new item
            new_item = GroceryItem(
                id=item_id,
                user_id=current_user.id,
                name=item_data.name,
                category=item_data.category.value,
                storage_location=item_data.storage_location.value,
                quantity=item_data.quantity,
                unit=item_data.unit,
                purchase_date=item_data.purchase_date,
                expiration_date=item_data.expiration_date,
                predicted_expiration_date=item_data.predicted_expiration_date,
                confidence_score=item_data.confidence_score,
                barcode=item_data.barcode,
                notes=item_data.notes,
            )
            db.add(new_item)

    await db.commit()

    # Get all items for response
    result = await db.execute(
        select(GroceryItem).where(GroceryItem.user_id == current_user.id)
    )
    all_items = result.scalars().all()

    return GrocerySyncResponse(
        items=[grocery_to_response(item) for item in all_items],
        deleted_ids=server_deleted_ids,
        sync_timestamp=sync_timestamp,
    )
