import json
from typing import Optional

import httpx
import redis.asyncio as redis

from app.config import settings


class BarcodeService:
    """Service for looking up product information by barcode.

    Uses Redis caching with Open Food Facts API as the data source.
    """

    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self.http_client: Optional[httpx.AsyncClient] = None

    async def initialize(self):
        """Create Redis and HTTP client connections."""
        self.redis_client = redis.from_url(
            settings.REDIS_URL, decode_responses=True
        )
        self.http_client = httpx.AsyncClient(timeout=10.0)

    async def close(self):
        """Clean up connections."""
        if self.redis_client:
            await self.redis_client.close()
        if self.http_client:
            await self.http_client.aclose()

    async def lookup(self, barcode: str) -> Optional[dict]:
        """Look up a barcode, checking cache first, then Open Food Facts."""
        cache_key = f"barcode:{barcode}"

        # 1. Check Redis cache
        try:
            cached = await self.redis_client.get(cache_key)
            if cached:
                data = json.loads(cached)
                return data  # may be None (negative cache)
        except Exception:
            pass  # Redis down — fall through to API

        # 2. Query Open Food Facts
        product = await self._query_open_food_facts(barcode)

        # 3. Cache result
        try:
            if product:
                # Found: cache for 7 days
                await self.redis_client.setex(
                    cache_key, 604800, json.dumps(product)
                )
            else:
                # Not found: negative cache for 1 hour
                await self.redis_client.setex(
                    cache_key, 3600, json.dumps(None)
                )
        except Exception:
            pass  # Redis down — still return result

        return product

    async def _query_open_food_facts(self, barcode: str) -> Optional[dict]:
        """Query Open Food Facts API for product data."""
        url = f"https://world.openfoodfacts.org/api/v2/product/{barcode}"
        headers = {"User-Agent": settings.OPEN_FOOD_FACTS_USER_AGENT}

        try:
            response = await self.http_client.get(url, headers=headers)
        except httpx.HTTPError:
            return None

        if response.status_code != 200:
            return None

        data = response.json()
        if data.get("status") != 1:
            return None

        product = data.get("product", {})
        return self._parse_product(product, barcode)

    def _parse_product(self, product: dict, barcode: str) -> Optional[dict]:
        """Parse Open Food Facts product into our response format."""
        name = product.get("product_name", "").strip()
        if not name:
            return None

        categories_tags = product.get("categories_tags", [])
        suggested_category = self._map_category(categories_tags)

        return {
            "barcode": barcode,
            "name": name,
            "brand": product.get("brands", ""),
            "categories": product.get("categories", ""),
            "suggested_category": suggested_category,
            "quantity_string": product.get("quantity", ""),
            "image_url": product.get("image_front_url", ""),
            "ingredients_text": product.get("ingredients_text", ""),
            "nutriscore_grade": product.get("nutriscore_grade", ""),
        }

    def _map_category(self, categories_tags: list[str]) -> str:
        """Map Open Food Facts category tags to FoodCategory enum values."""
        mapping = {
            "dairy": "Dairy", "milk": "Dairy", "cheese": "Dairy",
            "yogurt": "Dairy", "butter": "Dairy",
            "meat": "Meat", "beef": "Meat", "pork": "Meat",
            "chicken": "Meat", "turkey": "Meat", "sausage": "Meat",
            "fish": "Seafood", "seafood": "Seafood", "shrimp": "Seafood",
            "tuna": "Seafood", "salmon": "Seafood",
            "fruit": "Produce", "vegetable": "Produce", "salad": "Produce",
            "bread": "Bakery", "pastry": "Bakery", "cake": "Bakery",
            "frozen": "Frozen", "ice-cream": "Frozen",
            "beverage": "Beverages", "drink": "Beverages", "juice": "Beverages",
            "water": "Beverages", "soda": "Beverages", "coffee": "Beverages",
            "tea": "Beverages",
            "sauce": "Condiments", "condiment": "Condiments",
            "ketchup": "Condiments", "mustard": "Condiments",
            "mayonnaise": "Condiments",
            "snack": "Snacks", "chip": "Snacks", "cookie": "Snacks",
            "cracker": "Snacks", "candy": "Snacks", "chocolate": "Snacks",
            "cereal": "Pantry", "pasta": "Pantry", "rice": "Pantry",
            "canned": "Pantry", "flour": "Pantry", "sugar": "Pantry",
            "oil": "Pantry",
        }
        for tag in categories_tags:
            tag_lower = tag.lower()
            for keyword, category in mapping.items():
                if keyword in tag_lower:
                    return category
        return "Other"


barcode_service = BarcodeService()
