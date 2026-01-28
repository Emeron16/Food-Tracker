from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from datetime import datetime, timezone
from typing import Annotated
import json

from app.db import get_db
from app.db.models import User
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.api.v1.schemas.user import (
    UserCreate,
    UserLogin,
    UserResponse,
    Token,
    TokenResponse,
    AppleSignInRequest,
)

router = APIRouter(prefix="/auth", tags=["authentication"])


async def get_current_user(
    db: Annotated[AsyncSession, Depends(get_db)],
    token: str = Depends(lambda: None)  # Will be replaced with proper OAuth2
) -> User:
    """Dependency to get current authenticated user."""
    # This is a simplified version - in production, use OAuth2PasswordBearer
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not token:
        raise credentials_exception

    payload = decode_token(token)
    if payload is None:
        raise credentials_exception

    user_id: str = payload.get("sub")
    if user_id is None:
        raise credentials_exception

    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise credentials_exception

    return user


def parse_json_list(json_str: str | None) -> list[str]:
    """Parse JSON string to list."""
    if not json_str:
        return []
    try:
        return json.loads(json_str)
    except json.JSONDecodeError:
        return []


def user_to_response(user: User) -> UserResponse:
    """Convert User model to response schema."""
    return UserResponse(
        id=user.id,
        email=user.email,
        full_name=user.full_name,
        household_size=user.household_size,
        cooking_skill_level=user.cooking_skill_level,
        dietary_restrictions=parse_json_list(user.dietary_restrictions),
        allergies=parse_json_list(user.allergies),
        preferred_cuisines=parse_json_list(user.preferred_cuisines),
        notifications_enabled=user.notifications_enabled,
        expiration_warning_days=user.expiration_warning_days,
        is_active=user.is_active,
        is_verified=user.is_verified,
        created_at=user.created_at,
    )


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
):
    """
    Register a new user with email and password.
    """
    # Check if user already exists
    result = await db.execute(select(User).where(User.email == user_data.email))
    existing_user = result.scalar_one_or_none()

    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )

    # Create new user
    user = User(
        email=user_data.email,
        hashed_password=get_password_hash(user_data.password),
        full_name=user_data.full_name,
    )

    db.add(user)
    await db.commit()
    await db.refresh(user)

    # Generate tokens
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(subject=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=user_to_response(user)
    )


@router.post("/login", response_model=TokenResponse)
async def login(
    credentials: UserLogin,
    db: AsyncSession = Depends(get_db)
):
    """
    Authenticate user with email and password.
    """
    # Find user by email
    result = await db.execute(select(User).where(User.email == credentials.email))
    user = result.scalar_one_or_none()

    if not user or not user.hashed_password:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )

    if not verify_password(credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password"
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User account is disabled"
        )

    # Update last login
    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()

    # Generate tokens
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(subject=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=user_to_response(user)
    )


@router.post("/apple", response_model=TokenResponse)
async def apple_sign_in(
    request: AppleSignInRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    Sign in with Apple. Creates a new user if they don't exist.
    """
    # In production, verify the identity_token with Apple's servers
    # For now, we trust the client-provided data

    # Check if user exists by Apple ID
    result = await db.execute(
        select(User).where(User.apple_user_id == request.user_identifier)
    )
    user = result.scalar_one_or_none()

    if user:
        # Existing user - update last login
        user.last_login_at = datetime.now(timezone.utc)
        await db.commit()
    else:
        # New user - check if email exists
        if request.email:
            result = await db.execute(select(User).where(User.email == request.email))
            existing_user = result.scalar_one_or_none()

            if existing_user:
                # Link Apple ID to existing account
                existing_user.apple_user_id = request.user_identifier
                existing_user.is_verified = True
                existing_user.last_login_at = datetime.now(timezone.utc)
                user = existing_user
            else:
                # Create new user
                user = User(
                    email=request.email,
                    apple_user_id=request.user_identifier,
                    full_name=request.full_name,
                    is_verified=True,
                )
                db.add(user)
        else:
            # No email provided - create user with placeholder
            user = User(
                email=f"{request.user_identifier}@privaterelay.appleid.com",
                apple_user_id=request.user_identifier,
                full_name=request.full_name,
                is_verified=True,
            )
            db.add(user)

        await db.commit()
        await db.refresh(user)

    # Generate tokens
    access_token = create_access_token(subject=user.id)
    refresh_token = create_refresh_token(subject=user.id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="bearer",
        user=user_to_response(user)
    )


@router.post("/refresh", response_model=Token)
async def refresh_token(
    refresh_token: str,
    db: AsyncSession = Depends(get_db)
):
    """
    Get a new access token using a refresh token.
    """
    payload = decode_token(refresh_token)

    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token"
        )

    user_id = payload.get("sub")

    # Verify user still exists and is active
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive"
        )

    # Generate new tokens
    new_access_token = create_access_token(subject=user.id)
    new_refresh_token = create_refresh_token(subject=user.id)

    return Token(
        access_token=new_access_token,
        refresh_token=new_refresh_token,
        token_type="bearer"
    )


@router.post("/logout")
async def logout():
    """
    Logout user. In a production system, this would invalidate the tokens.
    """
    # For a stateless JWT system, logout is typically handled client-side
    # For a more robust solution, use a token blacklist in Redis
    return {"message": "Successfully logged out"}
