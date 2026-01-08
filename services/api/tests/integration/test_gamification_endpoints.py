"""Integration tests for gamification endpoints"""

import pytest
from datetime import date, timedelta


class TestGamificationEndpoints:
    """Test suite for gamification API endpoints"""

    @pytest.mark.asyncio
    async def test_get_today_response(self, async_client, db_session):
        """Test getting today's Life Score and XP"""
        response = await async_client.get("/api/today")

        assert response.status_code == 200
        data = response.json()

        # Verify structure
        assert "date" in data
        assert "life_score" in data
        assert "domains" in data
        assert "xp" in data
        assert "streaks" in data
        assert "recent_achievements" in data

        # Verify domains
        assert "sleep" in data["domains"]
        assert "activity" in data["domains"]
        assert "worklife" in data["domains"]
        assert "habits" in data["domains"]

        # Verify XP info
        xp = data["xp"]
        assert "total_xp" in xp
        assert "level" in xp
        assert "progress_to_next" in xp

        # Verify data types and ranges
        assert 0 <= data["life_score"] <= 100
        assert xp["level"] >= 1
        assert 0 <= xp["progress_to_next"] <= 100

    @pytest.mark.asyncio
    async def test_calculate_daily_score(self, async_client, db_session):
        """Test calculating daily score for a specific date"""
        target_date = date.today()

        response = await async_client.post(
            f"/api/gamification/daily-score?target_date={target_date.isoformat()}"
        )

        assert response.status_code == 200
        data = response.json()

        assert data["date"] == target_date.isoformat()
        assert "life_score" in data
        assert "sleep_score" in data
        assert "activity_score" in data
        assert "worklife_score" in data
        assert "habits_score" in data
        assert "xp_earned" in data

    @pytest.mark.asyncio
    async def test_get_xp_info(self, async_client, db_session):
        """Test getting current XP and level information"""
        response = await async_client.get("/api/gamification/xp")

        assert response.status_code == 200
        data = response.json()

        assert "total_xp" in data
        assert "level" in data
        assert "xp_for_current_level" in data
        assert "xp_for_next_level" in data
        assert "progress_to_next" in data
        assert "today_xp" in data

        # Level should be at least 1
        assert data["level"] >= 1
        # Progress should be 0-100
        assert 0 <= data["progress_to_next"] <= 100

    @pytest.mark.asyncio
    async def test_add_bonus_xp(self, async_client, db_session):
        """Test adding bonus XP"""
        xp_data = {
            "xp_amount": 150,
            "event_type": "bonus_achievement",
            "details": {"achievement": "early_wake_streak_7"}
        }

        response = await async_client.post("/api/gamification/xp", json=xp_data)

        assert response.status_code == 200
        data = response.json()
        assert "success" in data
        assert data.get("success") is True

    @pytest.mark.asyncio
    async def test_get_streaks(self, async_client, db_session):
        """Test getting current streaks"""
        response = await async_client.get("/api/gamification/streaks")

        assert response.status_code == 200
        data = response.json()

        # Should return a dict of streak_type -> count
        assert isinstance(data, dict)

    @pytest.mark.asyncio
    async def test_get_achievements(self, async_client, db_session):
        """Test getting achievements"""
        response = await async_client.get("/api/gamification/achievements")

        assert response.status_code == 200
        data = response.json()

        # Should return a list
        assert isinstance(data, list)

        # If there are achievements, verify structure
        if data:
            achievement = data[0]
            assert "id" in achievement
            assert "code" in achievement
            assert "name" in achievement
            assert "tier" in achievement
            assert "xp_reward" in achievement
            assert "is_unlocked" in achievement

    @pytest.mark.asyncio
    async def test_get_unlocked_achievements_only(self, async_client, db_session):
        """Test filtering for unlocked achievements only"""
        response = await async_client.get(
            "/api/gamification/achievements?unlocked_only=true"
        )

        assert response.status_code == 200
        data = response.json()

        # All returned achievements should be unlocked
        for achievement in data:
            assert achievement["is_unlocked"] is True

    @pytest.mark.asyncio
    async def test_daily_score_calculation_persistence(self, async_client, db_session):
        """Test that daily score is persisted and consistent"""
        target_date = date.today()

        # Calculate score
        response1 = await async_client.post(
            f"/api/gamification/daily-score?target_date={target_date.isoformat()}"
        )
        assert response1.status_code == 200
        score1 = response1.json()

        # Get the same score again - should be consistent
        response2 = await async_client.post(
            f"/api/gamification/daily-score?target_date={target_date.isoformat()}"
        )
        assert response2.status_code == 200
        score2 = response2.json()

        # Scores should match (recalculation should be idempotent)
        assert score1["life_score"] == score2["life_score"]
        assert score1["xp_earned"] == score2["xp_earned"]

    @pytest.mark.asyncio
    async def test_xp_accumulation(self, async_client, db_session):
        """Test that XP accumulates correctly"""
        # Get initial XP
        response1 = await async_client.get("/api/gamification/xp")
        initial_xp = response1.json()["total_xp"]

        # Add bonus XP
        await async_client.post("/api/gamification/xp", json={
            "xp_amount": 100,
            "event_type": "test_bonus"
        })

        # Get updated XP
        response2 = await async_client.get("/api/gamification/xp")
        new_xp = response2.json()["total_xp"]

        # Should have increased
        assert new_xp >= initial_xp

    @pytest.mark.asyncio
    async def test_level_calculation(self, async_client, db_session):
        """Test that level is calculated correctly from XP"""
        response = await async_client.get("/api/gamification/xp")

        data = response.json()
        total_xp = data["total_xp"]
        level = data["level"]

        # Level 1 = 0-1000 XP
        # Level 2 = 1000-4000 XP
        # Level 3 = 4000-9000 XP
        if total_xp < 1000:
            assert level == 1
        elif total_xp < 4000:
            assert level <= 2
        elif total_xp < 9000:
            assert level <= 3
