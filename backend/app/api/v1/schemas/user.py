from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime


class UserCreate(BaseModel):
    """Schema for user registration."""
    email: EmailStr
    password: str = Field(..., min_length=8, max_length=100)
    full_name: Optional[str] = Field(None, max_length=255)


class UserLogin(BaseModel):
    """Schema for user login."""
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    """Schema for user response."""
    id: str
    email: str
    full_name: Optional[str] = None
    household_size: int
    cooking_skill_level: int
    dietary_restrictions: Optional[list[str]] = None
    allergies: Optional[list[str]] = None
    preferred_cuisines: Optional[list[str]] = None
    notifications_enabled: bool
    expiration_warning_days: int
    is_active: bool
    is_verified: bool
    created_at: datetime

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    """Schema for updating user profile."""
    full_name: Optional[str] = Field(None, max_length=255)
    household_size: Optional[int] = Field(None, ge=1, le=20)
    cooking_skill_level: Optional[int] = Field(None, ge=1, le=5)
    dietary_restrictions: Optional[list[str]] = None
    allergies: Optional[list[str]] = None
    preferred_cuisines: Optional[list[str]] = None
    notifications_enabled: Optional[bool] = None
    expiration_warning_days: Optional[int] = Field(None, ge=1, le=14)


class Token(BaseModel):
    """Token model."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenResponse(BaseModel):
    """Token response with user info."""
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserResponse


class AppleSignInRequest(BaseModel):
    """Schema for Sign in with Apple."""
    identity_token: str
    authorization_code: str
    user_identifier: str
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None


class RefreshTokenRequest(BaseModel):
    """Schema for token refresh."""
    refresh_token: str


class PasswordChangeRequest(BaseModel):
    """Schema for password change."""
    current_password: str
    new_password: str = Field(..., min_length=8, max_length=100)
