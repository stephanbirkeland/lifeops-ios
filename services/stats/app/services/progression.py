"""Progression service - XP calculations and level management"""

from typing import Optional
import math
import re


class ProgressionService:
    """Service for XP and level calculations"""

    # Level XP formula: 100 * (level - 1)^1.8
    # Stat XP formula: 50 * (level - 10)^1.5

    def level_from_xp(self, xp: int) -> int:
        """Calculate character level from total XP"""
        if xp <= 0:
            return 1

        # Solve: xp = 100 * (level - 1)^1.8
        # level = (xp / 100)^(1/1.8) + 1
        level = int(math.pow(xp / 100, 1 / 1.8) + 1)

        # Verify and adjust
        while self.xp_for_level(level + 1) <= xp:
            level += 1

        return min(level, 100)

    def xp_for_level(self, level: int) -> int:
        """Calculate XP required to reach a level"""
        if level <= 1:
            return 0
        return int(100 * math.pow(level - 1, 1.8))

    def xp_for_next_level(self, current_level: int) -> int:
        """Calculate XP required for next level"""
        return self.xp_for_level(current_level + 1)

    def level_progress(self, xp: int, level: int) -> float:
        """Calculate progress percentage to next level"""
        current_threshold = self.xp_for_level(level)
        next_threshold = self.xp_for_level(level + 1)

        if next_threshold <= current_threshold:
            return 100.0

        progress = (xp - current_threshold) / (next_threshold - current_threshold)
        return round(min(max(progress * 100, 0), 100), 2)

    def stat_points_for_level(self, level: int) -> int:
        """Calculate stat points granted at a level"""
        if level % 10 == 0:
            return 3  # Major levels (10, 20, 30...)
        elif level % 5 == 0:
            return 2  # Notable levels (5, 15, 25...)
        return 1  # Regular levels

    def stat_level_from_xp(self, xp: int) -> int:
        """Calculate stat base value from stat XP"""
        if xp <= 0:
            return 10

        # Solve: xp = 50 * (level - 10)^1.5
        # level = (xp / 50)^(1/1.5) + 10
        level = int(math.pow(xp / 50, 1 / 1.5) + 10)

        # Verify and adjust
        while self.stat_xp_for_level(level + 1) <= xp:
            level += 1

        return min(level, 100)

    def stat_xp_for_level(self, level: int) -> int:
        """Calculate stat XP required to reach a stat level"""
        if level <= 10:
            return 0
        return int(50 * math.pow(level - 10, 1.5))

    def stat_xp_for_next_level(self, current_level: int) -> int:
        """Calculate stat XP required for next stat level"""
        return self.stat_xp_for_level(current_level + 1)

    def evaluate_formula(self, formula: str, stats: dict[str, int]) -> float:
        """
        Safely evaluate a stat formula.

        Example formulas:
        - "STR * 0.6 + INT * 0.4"
        - "STA * 0.7 + WIS * 0.3"
        """
        # Only allow safe characters: stat codes, numbers, operators, spaces, parentheses
        safe_pattern = r'^[\s\d\.\+\-\*\/\(\)STRINWISACHLCK]+$'
        if not re.match(safe_pattern, formula):
            raise ValueError(f"Invalid formula: {formula}")

        # Replace stat codes with values
        expr = formula
        for code, value in stats.items():
            expr = expr.replace(code, str(value))

        # Evaluate safely
        try:
            # Only allow basic math operations
            allowed_names = {"__builtins__": {}}
            result = eval(expr, allowed_names, {})
            return float(result)
        except Exception as e:
            raise ValueError(f"Failed to evaluate formula: {formula}") from e

    def calculate_level_ups(self, old_xp: int, new_xp: int) -> tuple[int, int, int]:
        """
        Calculate level changes from XP gain.

        Returns: (old_level, new_level, stat_points_earned)
        """
        old_level = self.level_from_xp(old_xp)
        new_level = self.level_from_xp(new_xp)

        stat_points = 0
        for level in range(old_level + 1, new_level + 1):
            stat_points += self.stat_points_for_level(level)

        return old_level, new_level, stat_points

    def calculate_stat_level_ups(
        self, stat_code: str, old_xp: int, new_xp: int
    ) -> tuple[int, int, bool]:
        """
        Calculate stat level changes from XP gain.

        Returns: (old_level, new_level, leveled_up)
        """
        old_level = self.stat_level_from_xp(old_xp)
        new_level = self.stat_level_from_xp(new_xp)

        return old_level, new_level, new_level > old_level
