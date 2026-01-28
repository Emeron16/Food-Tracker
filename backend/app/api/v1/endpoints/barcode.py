from fastapi import APIRouter, HTTPException, status

from app.services.barcode_service import barcode_service
from app.api.v1.schemas.barcode import BarcodeProductResponse

router = APIRouter(prefix="/barcode", tags=["barcode"])


@router.get("/{barcode}", response_model=BarcodeProductResponse)
async def lookup_barcode(barcode: str):
    """
    Look up a product by barcode.

    Checks Redis cache first, then queries Open Food Facts.
    No authentication required.
    """
    cleaned = barcode.strip()

    # Validate barcode format (EAN-8, UPC-A, EAN-13, ITF-14)
    if not cleaned.isdigit() or len(cleaned) not in (8, 12, 13, 14):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid barcode format. Expected 8, 12, 13, or 14 digit numeric code.",
        )

    result = await barcode_service.lookup(cleaned)

    if not result or not result.get("name"):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product not found for barcode: {cleaned}",
        )

    return BarcodeProductResponse(**result, source="open_food_facts")
