"""Spoonacular API service for recipe search and details."""

import json
from typing import Optional

import httpx
import redis.asyncio as redis

from app.config import settings


class SpoonacularService:
    """Service for searching recipes via the Spoonacular API.

    Uses Redis caching to minimize API calls.
    """

    BASE_URL = "https://api.spoonacular.com"

    def __init__(self):
        self.redis_client: Optional[redis.Redis] = None
        self.http_client: Optional[httpx.AsyncClient] = None

    async def initialize(self):
        """Create Redis and HTTP client connections."""
        self.redis_client = redis.from_url(
            settings.REDIS_URL, decode_responses=True
        )
        self.http_client = httpx.AsyncClient(timeout=15.0)

    async def close(self):
        """Clean up connections."""
        if self.redis_client:
            await self.redis_client.close()
        if self.http_client:
            await self.http_client.aclose()

    async def search_recipes(
        self,
        query: Optional[str] = None,
        ingredients: Optional[list[str]] = None,
        diet: Optional[str] = None,
        max_ready_time: Optional[int] = None,
        number: int = 10,
        offset: int = 0,
    ) -> dict:
        """Search for recipes with various filters.

        Args:
            query: Search query string
            ingredients: List of ingredients to include
            diet: Diet type (vegetarian, vegan, glutenFree, etc.)
            max_ready_time: Maximum preparation time in minutes
            number: Number of results to return (max 100)
            offset: Number of results to skip for pagination

        Returns:
            Dict with 'results' list and 'totalResults' count
        """
        # Build cache key
        cache_parts = [
            f"q:{query or ''}",
            f"i:{','.join(sorted(ingredients)) if ingredients else ''}",
            f"d:{diet or ''}",
            f"t:{max_ready_time or ''}",
            f"n:{number}",
            f"o:{offset}",
        ]
        cache_key = f"recipes:search:{':'.join(cache_parts)}"

        # Check cache
        try:
            cached = await self.redis_client.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

        # Build API request
        params = {
            "apiKey": settings.SPOONACULAR_API_KEY,
            "number": min(number, 100),
            "offset": offset,
            "addRecipeInformation": True,
            "fillIngredients": True,
        }

        if query:
            params["query"] = query
        if ingredients:
            params["includeIngredients"] = ",".join(ingredients)
        if diet:
            params["diet"] = diet
        if max_ready_time:
            params["maxReadyTime"] = max_ready_time

        try:
            response = await self.http_client.get(
                f"{self.BASE_URL}/recipes/complexSearch",
                params=params,
            )
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPError:
            return {"results": [], "totalResults": 0}

        # Parse results
        result = {
            "results": [self._parse_recipe_summary(r) for r in data.get("results", [])],
            "totalResults": data.get("totalResults", 0),
        }

        # Cache for 1 hour
        try:
            await self.redis_client.setex(cache_key, 3600, json.dumps(result))
        except Exception:
            pass

        return result

    async def search_by_ingredients(
        self,
        ingredients: list[str],
        number: int = 10,
        ranking: int = 1,
    ) -> list[dict]:
        """Search recipes by available ingredients.

        Args:
            ingredients: List of ingredients the user has
            number: Number of results to return
            ranking: 1 = maximize used ingredients, 2 = minimize missing ingredients

        Returns:
            List of recipe summaries with used/missed ingredient info
        """
        cache_key = f"recipes:byingredients:{','.join(sorted(ingredients))}:{number}:{ranking}"

        try:
            cached = await self.redis_client.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

        params = {
            "apiKey": settings.SPOONACULAR_API_KEY,
            "ingredients": ",".join(ingredients),
            "number": min(number, 100),
            "ranking": ranking,
            "ignorePantry": True,
        }

        try:
            response = await self.http_client.get(
                f"{self.BASE_URL}/recipes/findByIngredients",
                params=params,
            )
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPError:
            return []

        results = [self._parse_ingredient_search_result(r) for r in data]

        try:
            await self.redis_client.setex(cache_key, 3600, json.dumps(results))
        except Exception:
            pass

        return results

    async def get_recipe_details(self, recipe_id: int) -> Optional[dict]:
        """Get full recipe details including instructions.

        Args:
            recipe_id: Spoonacular recipe ID

        Returns:
            Full recipe details or None if not found
        """
        cache_key = f"recipes:detail:{recipe_id}"

        try:
            cached = await self.redis_client.get(cache_key)
            if cached:
                return json.loads(cached)
        except Exception:
            pass

        params = {
            "apiKey": settings.SPOONACULAR_API_KEY,
            "includeNutrition": False,
        }

        try:
            response = await self.http_client.get(
                f"{self.BASE_URL}/recipes/{recipe_id}/information",
                params=params,
            )
            if response.status_code == 404:
                return None
            response.raise_for_status()
            data = response.json()
        except httpx.HTTPError:
            return None

        result = self._parse_recipe_detail(data)

        # Cache for 24 hours
        try:
            await self.redis_client.setex(cache_key, 86400, json.dumps(result))
        except Exception:
            pass

        return result

    def _parse_recipe_summary(self, data: dict) -> dict:
        """Parse recipe data into summary format."""
        return {
            "id": data.get("id"),
            "title": data.get("title", ""),
            "image": data.get("image", ""),
            "ready_in_minutes": data.get("readyInMinutes"),
            "servings": data.get("servings"),
            "source_url": data.get("sourceUrl", ""),
            "diets": data.get("diets", []),
            "dish_types": data.get("dishTypes", []),
            "vegetarian": data.get("vegetarian", False),
            "vegan": data.get("vegan", False),
            "gluten_free": data.get("glutenFree", False),
            "dairy_free": data.get("dairyFree", False),
            "health_score": data.get("healthScore"),
        }

    def _parse_ingredient_search_result(self, data: dict) -> dict:
        """Parse ingredient search result."""
        return {
            "id": data.get("id"),
            "title": data.get("title", ""),
            "image": data.get("image", ""),
            "used_ingredient_count": data.get("usedIngredientCount", 0),
            "missed_ingredient_count": data.get("missedIngredientCount", 0),
            "used_ingredients": [
                {"name": i.get("name", ""), "image": i.get("image", "")}
                for i in data.get("usedIngredients", [])
            ],
            "missed_ingredients": [
                {"name": i.get("name", ""), "image": i.get("image", "")}
                for i in data.get("missedIngredients", [])
            ],
        }

    def _parse_recipe_detail(self, data: dict) -> dict:
        """Parse full recipe details."""
        # Parse ingredients
        ingredients = []
        for ing in data.get("extendedIngredients", []):
            ingredients.append({
                "id": ing.get("id"),
                "name": ing.get("name", ""),
                "original": ing.get("original", ""),
                "amount": ing.get("amount"),
                "unit": ing.get("unit", ""),
                "image": f"https://spoonacular.com/cdn/ingredients_100x100/{ing.get('image', '')}" if ing.get("image") else None,
            })

        # Parse instructions
        instructions = []
        analyzed = data.get("analyzedInstructions", [])
        if analyzed:
            for step in analyzed[0].get("steps", []):
                instructions.append({
                    "number": step.get("number"),
                    "step": step.get("step", ""),
                    "ingredients": [i.get("name", "") for i in step.get("ingredients", [])],
                    "equipment": [e.get("name", "") for e in step.get("equipment", [])],
                })

        return {
            "id": data.get("id"),
            "title": data.get("title", ""),
            "image": data.get("image", ""),
            "ready_in_minutes": data.get("readyInMinutes"),
            "servings": data.get("servings"),
            "source_url": data.get("sourceUrl", ""),
            "source_name": data.get("sourceName", ""),
            "summary": data.get("summary", ""),
            "diets": data.get("diets", []),
            "dish_types": data.get("dishTypes", []),
            "cuisines": data.get("cuisines", []),
            "vegetarian": data.get("vegetarian", False),
            "vegan": data.get("vegan", False),
            "gluten_free": data.get("glutenFree", False),
            "dairy_free": data.get("dairyFree", False),
            "health_score": data.get("healthScore"),
            "ingredients": ingredients,
            "instructions": instructions,
            "instructions_text": data.get("instructions", ""),
        }


spoonacular_service = SpoonacularService()
