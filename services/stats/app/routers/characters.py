"""Character endpoints"""

from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.character import Character, CharacterCreate, CharacterFull
from app.services.character import CharacterService

router = APIRouter(prefix="/characters", tags=["characters"])


@router.post("", response_model=Character, status_code=201)
async def create_character(
    data: CharacterCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a new character for a user"""
    service = CharacterService(db)
    try:
        return await service.create_character(data)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/user/{user_id}", response_model=Optional[Character])
async def get_character_by_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get character by user ID"""
    service = CharacterService(db)
    character = await service.get_by_user_id(user_id)
    if not character:
        raise HTTPException(status_code=404, detail="Character not found")
    return await service.get_character_response(character.id)


@router.get("/{character_id}", response_model=Character)
async def get_character(
    character_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get character by ID"""
    service = CharacterService(db)
    character = await service.get_character_response(character_id)
    if not character:
        raise HTTPException(status_code=404, detail="Character not found")
    return character


@router.get("/{character_id}/full", response_model=CharacterFull)
async def get_character_full(
    character_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get full character with detailed stats"""
    service = CharacterService(db)
    character = await service.get_character_full(character_id)
    if not character:
        raise HTTPException(status_code=404, detail="Character not found")
    return character


@router.patch("/{character_id}/name")
async def update_character_name(
    character_id: UUID,
    name: str,
    db: AsyncSession = Depends(get_db)
):
    """Update character name"""
    service = CharacterService(db)
    character = await service.update_name(character_id, name)
    if not character:
        raise HTTPException(status_code=404, detail="Character not found")
    return character


@router.get("/user/{user_id}/full", response_model=CharacterFull)
async def get_character_full_by_user(
    user_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get full character by user ID"""
    service = CharacterService(db)
    character = await service.get_by_user_id(user_id)
    if not character:
        raise HTTPException(status_code=404, detail="Character not found")
    return await service.get_character_full(character.id)
