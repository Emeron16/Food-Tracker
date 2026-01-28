from pydantic import BaseModel
from typing import Optional


class BarcodeProductResponse(BaseModel):
    """Response when a barcode product is found."""

    barcode: str
    name: str
    brand: Optional[str] = None
    categories: Optional[str] = None
    suggested_category: str = "Other"
    quantity_string: Optional[str] = None
    image_url: Optional[str] = None
    ingredients_text: Optional[str] = None
    nutriscore_grade: Optional[str] = None
    source: str = "open_food_facts"
