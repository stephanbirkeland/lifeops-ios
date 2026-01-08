"""Stat tree endpoints"""

from uuid import UUID
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.tree import (
    TreeResponse, AllocateRequest, AllocateResponse,
    RespecRequest, RespecResponse, StatNode
)
from app.services.tree_engine import TreeEngine

router = APIRouter(prefix="/tree", tags=["tree"])


@router.get("", response_model=TreeResponse)
async def get_tree(
    character_id: Optional[UUID] = None,
    db: AsyncSession = Depends(get_db)
):
    """
    Get the full stat tree structure.

    If character_id is provided, nodes will show allocation status.
    """
    engine = TreeEngine(db)
    return await engine.get_tree(character_id)


@router.get("/node/{code}", response_model=StatNode)
async def get_node(
    code: str,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific node by code"""
    engine = TreeEngine(db)
    node = await engine.get_node_by_code(code)
    if not node:
        raise HTTPException(status_code=404, detail="Node not found")
    return node


@router.get("/reachable/{character_id}")
async def get_reachable_nodes(
    character_id: UUID,
    db: AsyncSession = Depends(get_db)
):
    """Get all nodes reachable from current allocations"""
    engine = TreeEngine(db)
    reachable = await engine.get_reachable_nodes(character_id)
    return {"reachable_nodes": reachable}


@router.post("/allocate", response_model=AllocateResponse)
async def allocate_nodes(
    request: AllocateRequest,
    db: AsyncSession = Depends(get_db)
):
    """Allocate one or more nodes for a character"""
    engine = TreeEngine(db)
    return await engine.allocate_nodes(request.character_id, request.node_codes)


@router.post("/respec", response_model=RespecResponse)
async def respec(
    request: RespecRequest,
    db: AsyncSession = Depends(get_db)
):
    """Reset all node allocations (costs a respec token)"""
    engine = TreeEngine(db)
    response = await engine.respec(request.character_id)

    if not response.success and response.respec_tokens_remaining == 0:
        raise HTTPException(status_code=400, detail="No respec tokens available")

    return response


@router.get("/can-allocate/{character_id}/{node_code}")
async def check_can_allocate(
    character_id: UUID,
    node_code: str,
    db: AsyncSession = Depends(get_db)
):
    """Check if a character can allocate a specific node"""
    engine = TreeEngine(db)
    can_alloc, reason = await engine.can_allocate(character_id, node_code)
    return {
        "can_allocate": can_alloc,
        "reason": reason
    }
