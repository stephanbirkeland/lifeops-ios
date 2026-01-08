"""Tree engine - Graph traversal and node allocation"""

from uuid import UUID
from typing import Optional
from collections import defaultdict
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.tree import (
    StatNodeDB, StatNodeEdgeDB, CharacterNodeDB,
    StatNode, NodeEffect, TreeResponse, AllocateResponse, RespecResponse
)
from app.models.character import CharacterDB, CharacterStatDB


class TreeEngine:
    """Engine for stat tree operations"""

    def __init__(self, db: AsyncSession):
        self.db = db
        self._node_cache: dict[str, StatNodeDB] = {}
        self._edge_cache: dict[UUID, list[UUID]] = {}
        self._code_to_id: dict[str, UUID] = {}

    async def _load_cache(self):
        """Load tree structure into memory for fast traversal"""
        if self._node_cache:
            return

        # Load all nodes
        result = await self.db.execute(
            select(StatNodeDB).where(StatNodeDB.is_active == True)
        )
        nodes = result.scalars().all()

        for node in nodes:
            self._node_cache[node.code] = node
            self._code_to_id[node.code] = node.id

        # Load all edges
        result = await self.db.execute(select(StatNodeEdgeDB))
        edges = result.scalars().all()

        self._edge_cache = defaultdict(list)
        for edge in edges:
            self._edge_cache[edge.from_node_id].append(edge.to_node_id)
            if edge.bidirectional:
                self._edge_cache[edge.to_node_id].append(edge.from_node_id)

    async def get_tree(self, character_id: Optional[UUID] = None) -> TreeResponse:
        """Get full tree structure, optionally with character's allocations"""
        await self._load_cache()

        # Get character's allocated nodes if provided
        allocated_ids = set()
        if character_id:
            result = await self.db.execute(
                select(CharacterNodeDB.node_id)
                .where(CharacterNodeDB.character_id == character_id)
            )
            allocated_ids = {row[0] for row in result.fetchall()}

        # Build node list
        nodes = []
        for code, node_db in self._node_cache.items():
            # Parse effects from JSONB
            effects = []
            for e in (node_db.effects or []):
                effects.append(NodeEffect(**e))

            # Get prerequisite codes
            prereq_codes = []
            if node_db.prerequisite_nodes:
                for prereq_id in node_db.prerequisite_nodes:
                    for c, n in self._node_cache.items():
                        if n.id == prereq_id:
                            prereq_codes.append(c)
                            break

            nodes.append(StatNode(
                id=node_db.id,
                code=node_db.code,
                name=node_db.name,
                description=node_db.description,
                node_type=node_db.node_type,
                tree_branch=node_db.tree_branch,
                position_x=node_db.position_x or 0,
                position_y=node_db.position_y or 0,
                required_points=node_db.required_points or 1,
                prerequisite_codes=prereq_codes,
                effects=effects,
                icon=node_db.icon,
                is_allocated=node_db.id in allocated_ids
            ))

        # Build edge list (as code pairs)
        edges = []
        seen = set()
        for from_id, to_ids in self._edge_cache.items():
            from_code = None
            for c, n in self._node_cache.items():
                if n.id == from_id:
                    from_code = c
                    break
            if not from_code:
                continue

            for to_id in to_ids:
                to_code = None
                for c, n in self._node_cache.items():
                    if n.id == to_id:
                        to_code = c
                        break
                if not to_code:
                    continue

                # Avoid duplicates for bidirectional edges
                edge_key = tuple(sorted([from_code, to_code]))
                if edge_key not in seen:
                    edges.append((from_code, to_code))
                    seen.add(edge_key)

        # Group by branch
        branches = defaultdict(list)
        for node in nodes:
            if node.tree_branch:
                branches[node.tree_branch].append(node.code)

        return TreeResponse(
            nodes=nodes,
            edges=edges,
            branches=dict(branches)
        )

    async def can_allocate(
        self, character_id: UUID, node_code: str
    ) -> tuple[bool, str]:
        """Check if a character can allocate a node"""
        await self._load_cache()

        # Get node
        node = self._node_cache.get(node_code)
        if not node:
            return False, f"Node not found: {node_code}"

        # Get character
        result = await self.db.execute(
            select(CharacterDB).where(CharacterDB.id == character_id)
        )
        character = result.scalar_one_or_none()
        if not character:
            return False, "Character not found"

        # Check points
        if character.stat_points < (node.required_points or 1):
            return False, f"Not enough stat points (need {node.required_points})"

        # Get allocated nodes
        result = await self.db.execute(
            select(CharacterNodeDB.node_id)
            .where(CharacterNodeDB.character_id == character_id)
        )
        allocated_ids = {row[0] for row in result.fetchall()}

        # Check if already allocated
        if node.id in allocated_ids:
            return False, "Node already allocated"

        # Check reachability from allocated nodes (or origin for first allocation)
        if not await self._is_reachable(node.id, allocated_ids):
            return False, "Node not reachable from current allocations"

        return True, "OK"

    async def _is_reachable(
        self, target_id: UUID, allocated_ids: set[UUID]
    ) -> bool:
        """Check if target node is reachable from allocated nodes"""
        await self._load_cache()

        # If no allocations, only origin node is reachable
        if not allocated_ids:
            for node in self._node_cache.values():
                if node.id == target_id and node.node_type == "origin":
                    return True
            return False

        # BFS to check if target is adjacent to any allocated node
        for allocated_id in allocated_ids:
            connected = self._edge_cache.get(allocated_id, [])
            if target_id in connected:
                return True

        return False

    async def allocate_nodes(
        self, character_id: UUID, node_codes: list[str]
    ) -> AllocateResponse:
        """Allocate multiple nodes for a character"""
        await self._load_cache()

        errors = []
        allocated = []
        total_points = 0
        stat_changes = {}
        new_effects = []

        # Get character
        result = await self.db.execute(
            select(CharacterDB).where(CharacterDB.id == character_id)
        )
        character = result.scalar_one_or_none()
        if not character:
            return AllocateResponse(
                success=False,
                points_spent=0,
                points_remaining=0,
                nodes_allocated=[],
                stat_changes={},
                new_effects=[],
                errors=["Character not found"]
            )

        # Get current stats for tracking changes
        result = await self.db.execute(
            select(CharacterStatDB)
            .where(CharacterStatDB.character_id == character_id)
        )
        stats = {s.stat_code: s for s in result.scalars().all()}

        # Track stat changes
        for code in stats:
            stat_changes[code] = {
                "before": stats[code].base_value + stats[code].allocated_bonus,
                "after": stats[code].base_value + stats[code].allocated_bonus
            }

        # Process each node
        for code in node_codes:
            can_alloc, reason = await self.can_allocate(character_id, code)
            if not can_alloc:
                errors.append(f"{code}: {reason}")
                continue

            node = self._node_cache[code]
            points_needed = node.required_points or 1

            # Check points
            if character.stat_points < points_needed:
                errors.append(f"{code}: Not enough points")
                continue

            # Allocate
            character.stat_points -= points_needed
            total_points += points_needed

            char_node = CharacterNodeDB(
                character_id=character_id,
                node_id=node.id
            )
            self.db.add(char_node)
            allocated.append(code)

            # Apply effects
            for effect_data in (node.effects or []):
                effect = NodeEffect(**effect_data)
                new_effects.append(effect)

                # Apply stat bonuses
                if effect.type == "stat_bonus" and effect.stat:
                    if effect.stat in stats:
                        bonus = int(effect.value or 0)
                        stats[effect.stat].allocated_bonus += bonus
                        stat_changes[effect.stat]["after"] += bonus

        await self.db.commit()

        # Clear affected stat changes if no change
        stat_changes = {
            k: v for k, v in stat_changes.items()
            if v["before"] != v["after"]
        }

        return AllocateResponse(
            success=len(allocated) > 0,
            points_spent=total_points,
            points_remaining=character.stat_points,
            nodes_allocated=allocated,
            stat_changes=stat_changes,
            new_effects=new_effects,
            errors=errors
        )

    async def respec(self, character_id: UUID) -> RespecResponse:
        """Reset all node allocations for a character"""
        # Get character
        result = await self.db.execute(
            select(CharacterDB).where(CharacterDB.id == character_id)
        )
        character = result.scalar_one_or_none()
        if not character:
            return RespecResponse(
                success=False,
                nodes_removed=0,
                points_refunded=0,
                respec_tokens_remaining=0
            )

        # Check respec tokens
        if character.respec_tokens <= 0:
            return RespecResponse(
                success=False,
                nodes_removed=0,
                points_refunded=0,
                respec_tokens_remaining=0
            )

        # Count allocated nodes and calculate refund
        result = await self.db.execute(
            select(CharacterNodeDB)
            .where(CharacterNodeDB.character_id == character_id)
        )
        allocated_nodes = result.scalars().all()

        total_refund = 0
        for char_node in allocated_nodes:
            # Get node to find point cost
            result = await self.db.execute(
                select(StatNodeDB).where(StatNodeDB.id == char_node.node_id)
            )
            node = result.scalar_one_or_none()
            if node:
                total_refund += node.required_points or 1

        nodes_removed = len(allocated_nodes)

        # Delete allocations
        await self.db.execute(
            delete(CharacterNodeDB)
            .where(CharacterNodeDB.character_id == character_id)
        )

        # Reset allocated bonuses on stats
        result = await self.db.execute(
            select(CharacterStatDB)
            .where(CharacterStatDB.character_id == character_id)
        )
        for stat in result.scalars().all():
            stat.allocated_bonus = 0

        # Refund points and consume token
        character.stat_points += total_refund
        character.respec_tokens -= 1

        await self.db.commit()

        return RespecResponse(
            success=True,
            nodes_removed=nodes_removed,
            points_refunded=total_refund,
            respec_tokens_remaining=character.respec_tokens
        )

    async def get_node_by_code(self, code: str) -> Optional[StatNode]:
        """Get a single node by code"""
        await self._load_cache()

        node_db = self._node_cache.get(code)
        if not node_db:
            return None

        effects = [NodeEffect(**e) for e in (node_db.effects or [])]

        prereq_codes = []
        if node_db.prerequisite_nodes:
            for prereq_id in node_db.prerequisite_nodes:
                for c, n in self._node_cache.items():
                    if n.id == prereq_id:
                        prereq_codes.append(c)
                        break

        return StatNode(
            id=node_db.id,
            code=node_db.code,
            name=node_db.name,
            description=node_db.description,
            node_type=node_db.node_type,
            tree_branch=node_db.tree_branch,
            position_x=node_db.position_x or 0,
            position_y=node_db.position_y or 0,
            required_points=node_db.required_points or 1,
            prerequisite_codes=prereq_codes,
            effects=effects,
            icon=node_db.icon,
            is_allocated=False
        )

    async def get_reachable_nodes(self, character_id: UUID) -> list[str]:
        """Get codes of all nodes reachable from current allocations"""
        await self._load_cache()

        # Get allocated nodes
        result = await self.db.execute(
            select(CharacterNodeDB.node_id)
            .where(CharacterNodeDB.character_id == character_id)
        )
        allocated_ids = {row[0] for row in result.fetchall()}

        reachable = set()

        if not allocated_ids:
            # Only origin nodes are reachable
            for code, node in self._node_cache.items():
                if node.node_type == "origin":
                    reachable.add(code)
        else:
            # All adjacent unallocated nodes are reachable
            for alloc_id in allocated_ids:
                connected = self._edge_cache.get(alloc_id, [])
                for conn_id in connected:
                    if conn_id not in allocated_ids:
                        # Find code
                        for code, node in self._node_cache.items():
                            if node.id == conn_id:
                                reachable.add(code)
                                break

        return list(reachable)
