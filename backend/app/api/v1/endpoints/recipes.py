"""Recipe API endpoints."""

from fastapi import APIRouter, HTTPException, Query, status
from typing import Optional

from app.services.spoonacular_service import spoonacular_service
from app.api.v1.schemas.recipe import (
    RecipeSearchResponse,
    RecipeSummary,
    RecipeByIngredientResponse,
    RecipeByIngredientResult,
    RecipeDetail,
)

router = APIRouter(prefix="/recipes", tags=["recipes"])


@router.get("/search", response_model=RecipeSearchResponse)
async def search_recipes(
    query: Optional[str] = Query(None, description="Search query"),
    ingredients: Optional[str] = Query(None, description="Comma-separated ingredients to include"),
    diet: Optional[str] = Query(None, description="Diet type: vegetarian, vegan, glutenFree, etc."),
    max_ready_time: Optional[int] = Query(None, ge=1, le=300, description="Max preparation time in minutes"),
    number: int = Query(10, ge=1, le=50, description="Number of results"),
    offset: int = Query(0, ge=0, description="Offset for pagination"),
):
    """
    Search for recipes with various filters.

    - **query**: Text search for recipe names/descriptions
    - **ingredients**: Comma-separated list of ingredients to include
    - **diet**: Filter by diet (vegetarian, vegan, glutenFree, dairyFree, etc.)
    - **max_ready_time**: Maximum preparation time in minutes
    - **number**: Number of results to return (1-50)
    - **offset**: Pagination offset
    """
    ingredient_list = None
    if ingredients:
        ingredient_list = [i.strip() for i in ingredients.split(",") if i.strip()]

    result = await spoonacular_service.search_recipes(
        query=query,
        ingredients=ingredient_list,
        diet=diet,
        max_ready_time=max_ready_time,
        number=number,
        offset=offset,
    )

    return RecipeSearchResponse(
        results=[RecipeSummary(**r) for r in result["results"]],
        total_results=result["totalResults"],
    )


@router.get("/by-ingredients", response_model=RecipeByIngredientResponse)
async def search_by_ingredients(
    ingredients: str = Query(..., description="Comma-separated list of available ingredients"),
    number: int = Query(10, ge=1, le=50, description="Number of results"),
    maximize_used: bool = Query(True, description="True to maximize used ingredients, False to minimize missing"),
):
    """
    Find recipes based on available ingredients.

    This endpoint is ideal for the "Use Expiring Items" feature.

    - **ingredients**: Comma-separated list of ingredients you have
    - **number**: Number of results (1-50)
    - **maximize_used**: If true, prioritizes recipes that use more of your ingredients
    """
    ingredient_list = [i.strip() for i in ingredients.split(",") if i.strip()]

    if not ingredient_list:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one ingredient is required",
        )

    ranking = 1 if maximize_used else 2
    results = await spoonacular_service.search_by_ingredients(
        ingredients=ingredient_list,
        number=number,
        ranking=ranking,
    )

    return RecipeByIngredientResponse(
        results=[RecipeByIngredientResult(**r) for r in results]
    )


@router.get("/expiring", response_model=RecipeByIngredientResponse)
async def recipes_for_expiring_items(
    ingredients: str = Query(..., description="Comma-separated list of expiring ingredients"),
    number: int = Query(10, ge=1, le=20, description="Number of results"),
):
    """
    Get recipe suggestions for expiring ingredients.

    Prioritizes recipes that use as many of the expiring ingredients as possible.

    - **ingredients**: Comma-separated list of ingredients that are expiring soon
    - **number**: Number of results (1-20)
    """
    ingredient_list = [i.strip() for i in ingredients.split(",") if i.strip()]

    if not ingredient_list:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="At least one ingredient is required",
        )

    # Use ranking=1 to maximize used ingredients
    results = await spoonacular_service.search_by_ingredients(
        ingredients=ingredient_list,
        number=number,
        ranking=1,
    )

    return RecipeByIngredientResponse(
        results=[RecipeByIngredientResult(**r) for r in results]
    )


@router.get("/{recipe_id}", response_model=RecipeDetail)
async def get_recipe_detail(recipe_id: int):
    """
    Get full recipe details including ingredients and instructions.

    - **recipe_id**: Spoonacular recipe ID
    """
    result = await spoonacular_service.get_recipe_details(recipe_id)

    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Recipe not found: {recipe_id}",
        )

    return RecipeDetail(**result)
