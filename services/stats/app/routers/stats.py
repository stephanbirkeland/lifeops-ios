"""Stats endpoints"""

from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.character import StatDetail
from app.services.character import CharacterService

router = APIRouter(prefix="/stats", tags=["stats"])


@router.get("/{character_id}", response_model=dict[str, StatDetail])
async def get_stats(
    character_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get detailed stats for a character"""
    service = CharacterService(db)
    stats = await service.get_stats(character_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Character not found")
    return stats


@router.get("/{character_id}/{stat_code}", response_model=StatDetail)
async def get_stat(
    character_id: UUID,
    stat_code: str,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific stat for a character"""
    stat_code = stat_code.upper()
    if stat_code not in ["STR", "INT", "WIS", "STA", "CHA", "LCK"]:
        raise HTTPException(status_code=400, detail="Invalid stat code")

    service = CharacterService(db)
    stats = await service.get_stats(character_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Character not found")

    if stat_code not in stats:
        raise HTTPException(status_code=404, detail="Stat not found")

    return stats[stat_code]


@router.get("/{character_id}/derived")
async def get_derived_stats(
    character_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get derived stats for a character"""
    service = CharacterService(db)
    character = await service.get_character_full(character_id)
    if not character:
        raise HTTPException(status_code=404, detail="Character not found")

    return character.derived_stats
