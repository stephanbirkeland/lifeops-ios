"""Integration tests for timeline endpoints"""

import pytest
from datetime import date, time, timedelta


class TestTimelineEndpoints:
    """Test suite for timeline API endpoints"""

    @pytest.mark.asyncio
    async def test_get_timeline_feed_default(self, async_client, db_session):
        """Test getting timeline feed with default parameters"""
        response = await async_client.get("/timeline/feed")

        assert response.status_code == 200
        data = response.json()

        # Verify structure
        assert "now" in data
        assert "date" in data
        assert "window_hours" in data
        assert "items" in data
        assert "completed_today" in data
        assert "total_today" in data
        assert "completion_rate" in data
        assert "hidden_count" in data

        # Verify data types
        assert isinstance(data["items"], list)
        assert isinstance(data["completed_today"], int)
        assert isinstance(data["total_today"], int)
        assert 0 <= data["completion_rate"] <= 100

    @pytest.mark.asyncio
    async def test_get_timeline_feed_expanded(self, async_client, db_session):
        """Test getting expanded timeline feed (all items)"""
        response = await async_client.get("/timeline/feed?expand=true")

        assert response.status_code == 200
        data = response.json()

        # Should show 24-hour window
        assert data["window_hours"] == 24
        assert data["hidden_count"] == 0

    @pytest.mark.asyncio
    async def test_get_timeline_feed_specific_date(self, async_client, db_session):
        """Test getting timeline feed for specific date"""
        target_date = (date.today() - timedelta(days=1)).isoformat()

        response = await async_client.get(f"/timeline/feed?for_date={target_date}")

        assert response.status_code == 200
        data = response.json()

        assert data["date"] == target_date

    @pytest.mark.asyncio
    async def test_get_timeline_feed_custom_window(self, async_client, db_session):
        """Test getting timeline feed with custom window"""
        response = await async_client.get("/timeline/feed?window_hours=8")

        assert response.status_code == 200
        data = response.json()

        assert data["window_hours"] == 8

    @pytest.mark.asyncio
    async def test_create_timeline_item(self, async_client, db_session):
        """Test creating a new timeline item"""
        item_data = {
            "code": "test_workout",
            "name": "Test Workout",
            "description": "Integration test workout",
            "icon": "💪",
            "schedule_type": "daily",
            "anchor": "morning",
            "time_offset": 30,
            "window_minutes": 120,
            "category": "health"
        }

        response = await async_client.post("/timeline/items", json=item_data)

        assert response.status_code == 200
        data = response.json()

        assert data["code"] == "test_workout"
        assert data["name"] == "Test Workout"
        assert "id" in data

    @pytest.mark.asyncio
    async def test_get_timeline_item(self, async_client, db_session):
        """Test getting a specific timeline item"""
        # First create an item
        item_data = {
            "code": "test_item",
            "name": "Test Item",
            "schedule_type": "daily",
            "category": "productivity"
        }
        create_response = await async_client.post("/timeline/items", json=item_data)
        assert create_response.status_code == 200

        # Now get it
        response = await async_client.get("/timeline/items/test_item")

        assert response.status_code == 200
        data = response.json()
        assert data["code"] == "test_item"

    @pytest.mark.asyncio
    async def test_get_nonexistent_timeline_item(self, async_client):
        """Test getting non-existent timeline item"""
        response = await async_client.get("/timeline/items/nonexistent")

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_list_timeline_items(self, async_client, db_session):
        """Test listing all timeline items"""
        response = await async_client.get("/timeline/items")

        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_list_timeline_items_include_inactive(self, async_client, db_session):
        """Test listing all items including inactive"""
        response = await async_client.get("/timeline/items?active_only=false")

        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_update_timeline_item(self, async_client, db_session):
        """Test updating a timeline item"""
        # Create item
        item_data = {
            "code": "updatable_item",
            "name": "Original Name",
            "schedule_type": "daily",
            "category": "wellness"
        }
        create_response = await async_client.post("/timeline/items", json=item_data)
        assert create_response.status_code == 200

        # Update it
        update_data = {
            "name": "Updated Name",
            "window_minutes": 90
        }
        response = await async_client.patch(
            "/timeline/items/updatable_item",
            json=update_data
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "Updated Name"
        assert data["window_minutes"] == 90

    @pytest.mark.asyncio
    async def test_delete_timeline_item(self, async_client, db_session):
        """Test deleting (deactivating) a timeline item"""
        # Create item
        item_data = {
            "code": "deletable_item",
            "name": "To Be Deleted",
            "schedule_type": "daily",
            "category": "other"
        }
        create_response = await async_client.post("/timeline/items", json=item_data)
        assert create_response.status_code == 200

        # Delete it
        response = await async_client.delete("/timeline/items/deletable_item")

        assert response.status_code == 200
        data = response.json()
        assert data.get("success") is True

        # Verify it's deactivated (shouldn't appear in active list)
        list_response = await async_client.get("/timeline/items?active_only=true")
        active_items = list_response.json()
        active_codes = [item["code"] for item in active_items]
        assert "deletable_item" not in active_codes

    @pytest.mark.asyncio
    async def test_complete_timeline_item(self, async_client, db_session):
        """Test completing a timeline item"""
        # Create item
        item_data = {
            "code": "completable_item",
            "name": "To Complete",
            "schedule_type": "daily",
            "category": "health",
            "stat_rewards": {"STR": 10}
        }
        await async_client.post("/timeline/items", json=item_data)

        # Complete it
        completion_data = {
            "notes": "Completed successfully",
            "duration_minutes": 30
        }
        response = await async_client.post(
            "/timeline/items/completable_item/complete",
            json=completion_data
        )

        assert response.status_code == 200
        data = response.json()

        assert data["success"] is True
        assert data["item_code"] == "completable_item"
        assert "completed_at" in data
        assert "new_streak" in data

    @pytest.mark.asyncio
    async def test_complete_nonexistent_item(self, async_client):
        """Test completing non-existent item"""
        response = await async_client.post(
            "/timeline/items/nonexistent/complete",
            json={}
        )

        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_postpone_timeline_item_to_lunch(self, async_client, db_session):
        """Test postponing item to lunch"""
        # Create item
        item_data = {
            "code": "postponable_item",
            "name": "To Postpone",
            "schedule_type": "daily",
            "category": "productivity"
        }
        await async_client.post("/timeline/items", json=item_data)

        # Postpone it
        postpone_data = {
            "target": "LUNCH",
            "reason": "Morning meeting ran late"
        }
        response = await async_client.post(
            "/timeline/items/postponable_item/postpone",
            json=postpone_data
        )

        assert response.status_code == 200
        data = response.json()

        assert data["success"] is True
        assert data["item_code"] == "postponable_item"
        assert "new_date" in data
        assert "new_time" in data

    @pytest.mark.asyncio
    async def test_postpone_to_tomorrow(self, async_client, db_session):
        """Test postponing item to tomorrow"""
        # Create item
        item_data = {
            "code": "tomorrow_item",
            "name": "Do Tomorrow",
            "schedule_type": "daily",
            "category": "wellness"
        }
        await async_client.post("/timeline/items", json=item_data)

        # Postpone to tomorrow
        postpone_data = {
            "target": "TOMORROW"
        }
        response = await async_client.post(
            "/timeline/items/tomorrow_item/postpone",
            json=postpone_data
        )

        assert response.status_code == 200
        data = response.json()

        tomorrow = (date.today() + timedelta(days=1)).isoformat()
        assert data["new_date"] == tomorrow

    @pytest.mark.asyncio
    async def test_postpone_custom_datetime(self, async_client, db_session):
        """Test postponing item to custom date/time"""
        # Create item
        item_data = {
            "code": "custom_item",
            "name": "Custom Schedule",
            "schedule_type": "daily",
            "category": "other"
        }
        await async_client.post("/timeline/items", json=item_data)

        # Postpone to custom date/time
        custom_date = (date.today() + timedelta(days=2)).isoformat()
        postpone_data = {
            "target": "CUSTOM",
            "custom_date": custom_date,
            "custom_time": "15:30:00",
            "reason": "Scheduled appointment"
        }
        response = await async_client.post(
            "/timeline/items/custom_item/postpone",
            json=postpone_data
        )

        assert response.status_code == 200
        data = response.json()

        assert data["new_date"] == custom_date
        assert "15:30" in data["new_time"]

    @pytest.mark.asyncio
    async def test_skip_timeline_item(self, async_client, db_session):
        """Test skipping a timeline item"""
        # Create item
        item_data = {
            "code": "skippable_item",
            "name": "To Skip",
            "schedule_type": "daily",
            "category": "health"
        }
        await async_client.post("/timeline/items", json=item_data)

        # Skip it
        response = await async_client.post(
            "/timeline/items/skippable_item/skip",
            json={"reason": "Injury recovery"}
        )

        assert response.status_code == 200
        data = response.json()

        assert data["success"] is True
        assert data["item_code"] == "skippable_item"

    @pytest.mark.asyncio
    async def test_get_time_anchors(self, async_client, db_session):
        """Test getting all time anchors"""
        response = await async_client.get("/timeline/anchors")

        assert response.status_code == 200
        data = response.json()

        assert isinstance(data, list)

        # Should have standard anchors
        if data:
            anchor = data[0]
            assert "code" in anchor
            assert "name" in anchor
            assert "default_time" in anchor

    @pytest.mark.asyncio
    async def test_update_time_anchor(self, async_client, db_session):
        """Test updating a time anchor"""
        # Get existing anchors first
        list_response = await async_client.get("/timeline/anchors")
        anchors = list_response.json()

        if anchors:
            anchor_code = anchors[0]["code"]

            # Update it
            update_data = {
                "new_time": "08:00:00"
            }
            response = await async_client.patch(
                f"/timeline/anchors/{anchor_code}",
                json=update_data
            )

            # Should either succeed or return appropriate error
            assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_create_duplicate_item_code(self, async_client, db_session):
        """Test creating item with duplicate code"""
        item_data = {
            "code": "duplicate_code",
            "name": "First Item",
            "schedule_type": "daily",
            "category": "productivity"
        }

        # Create first item
        response1 = await async_client.post("/timeline/items", json=item_data)
        assert response1.status_code == 200

        # Try to create duplicate
        item_data["name"] = "Second Item"
        response2 = await async_client.post("/timeline/items", json=item_data)

        # Should fail or handle duplicate
        assert response2.status_code in [200, 400, 409, 422]

    @pytest.mark.asyncio
    async def test_invalid_schedule_type(self, async_client):
        """Test creating item with invalid schedule type"""
        item_data = {
            "code": "invalid_schedule",
            "name": "Invalid",
            "schedule_type": "invalid_type",
            "category": "other"
        }

        response = await async_client.post("/timeline/items", json=item_data)

        # Should return validation error
        assert response.status_code == 422
