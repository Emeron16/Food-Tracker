"""Recipe API schemas."""

from pydantic import BaseModel
from typing import Optional


class IngredientInfo(BaseModel):
    """Ingredient information for a recipe."""
    name: str
    image: Optional[str] = None


class RecipeIngredient(BaseModel):
    """Full ingredient details for recipe detail view."""
    id: Optional[int] = None
    name: str
    original: str
    amount: Optional[float] = None
    unit: str = ""
    image: Optional[str] = None


class RecipeInstruction(BaseModel):
    """Single instruction step."""
    number: int
    step: str
    ingredients: list[str] = []
    equipment: list[str] = []


class RecipeSummary(BaseModel):
    """Recipe summary for list views."""
    id: int
    title: str
    image: str = ""
    ready_in_minutes: Optional[int] = None
    servings: Optional[int] = None
    source_url: str = ""
    diets: list[str] = []
    dish_types: list[str] = []
    vegetarian: bool = False
    vegan: bool = False
    gluten_free: bool = False
    dairy_free: bool = False
    health_score: Optional[int] = None


class RecipeByIngredientResult(BaseModel):
    """Recipe result from ingredient-based search."""
    id: int
    title: str
    image: str = ""
    used_ingredient_count: int = 0
    missed_ingredient_count: int = 0
    used_ingredients: list[IngredientInfo] = []
    missed_ingredients: list[IngredientInfo] = []


class RecipeDetail(BaseModel):
    """Full recipe details."""
    id: int
    title: str
    image: str = ""
    ready_in_minutes: Optional[int] = None
    servings: Optional[int] = None
    source_url: str = ""
    source_name: str = ""
    summary: str = ""
    diets: list[str] = []
    dish_types: list[str] = []
    cuisines: list[str] = []
    vegetarian: bool = False
    vegan: bool = False
    gluten_free: bool = False
    dairy_free: bool = False
    health_score: Optional[int] = None
    ingredients: list[RecipeIngredient] = []
    instructions: list[RecipeInstruction] = []
    instructions_text: str = ""


class RecipeSearchResponse(BaseModel):
    """Response for recipe search endpoint."""
    results: list[RecipeSummary]
    total_results: int


class RecipeByIngredientResponse(BaseModel):
    """Response for search by ingredients endpoint."""
    results: list[RecipeByIngredientResult]
