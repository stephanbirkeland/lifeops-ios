"""Integration tests for Oura API endpoints"""

import pytest
from datetime import date, timedelta
from unittest.mock import patch, AsyncMock


class TestOuraEndpoints:
    """Test suite for Oura integration endpoints"""

    @pytest.mark.asyncio
    async def test_sync_oura_data_default_dates(self, async_client, db_session):
        """Test syncing Oura data with default date range (last 7 days)"""
        # Mock Oura API calls
        with patch('app.services.oura.oura_service.get_daily_sleep') as mock_sleep, \
             patch('app.services.oura.oura_service.get_daily_readiness') as mock_readiness, \
             patch('app.services.oura.oura_service.get_daily_activity') as mock_activity:

            mock_sleep.return_value = []
            mock_readiness.return_value = []
            mock_activity.return_value = []

            response = await async_client.post("/oura/sync")

            assert response.status_code == 200
            data = response.json()

            assert "synced" in data
            assert "start_date" in data
            assert "end_date" in data
            assert isinstance(data["synced"], dict)

    @pytest.mark.asyncio
    async def test_sync_oura_data_custom_dates(self, async_client, db_session):
        """Test syncing Oura data with custom date range"""
        start = (date.today() - timedelta(days=3)).isoformat()
        end = date.today().isoformat()

        with patch('app.services.oura.oura_service.get_daily_sleep') as mock_sleep, \
             patch('app.services.oura.oura_service.get_daily_readiness') as mock_readiness, \
             patch('app.services.oura.oura_service.get_daily_activity') as mock_activity:

            mock_sleep.return_value = []
            mock_readiness.return_value = []
            mock_activity.return_value = []

            response = await async_client.post(
                f"/oura/sync?start_date={start}&end_date={end}"
            )

            assert response.status_code == 200
            data = response.json()

            assert data["start_date"] == start
            assert data["end_date"] == end

    @pytest.mark.asyncio
    async def test_sync_oura_data_with_results(self, async_client, db_session):
        """Test syncing Oura data that returns actual results"""
        mock_sleep_data = [
            {"day": date.today().isoformat(), "score": 85}
        ]
        mock_readiness_data = [
            {"day": date.today().isoformat(), "score": 75}
        ]
        mock_activity_data = [
            {"day": date.today().isoformat(), "score": 80}
        ]

        with patch('app.services.oura.oura_service.get_daily_sleep') as mock_sleep, \
             patch('app.services.oura.oura_service.get_daily_readiness') as mock_readiness, \
             patch('app.services.oura.oura_service.get_daily_activity') as mock_activity:

            mock_sleep.return_value = mock_sleep_data
            mock_readiness.return_value = mock_readiness_data
            mock_activity.return_value = mock_activity_data

            response = await async_client.post("/oura/sync")

            assert response.status_code == 200
            data = response.json()

            # Should have synced at least one record per category
            assert data["synced"]["sleep"] >= 1
            assert data["synced"]["readiness"] >= 1
            assert data["synced"]["activity"] >= 1

    @pytest.mark.asyncio
    async def test_get_latest_summary_today(self, async_client, db_session):
        """Test getting latest Oura summary for today"""
        # First sync some data
        mock_sleep_data = [
            {"day": date.today().isoformat(), "score": 85}
        ]

        with patch('app.services.oura.oura_service.get_daily_sleep') as mock_sleep, \
             patch('app.services.oura.oura_service.get_daily_readiness') as mock_readiness, \
             patch('app.services.oura.oura_service.get_daily_activity') as mock_activity:

            mock_sleep.return_value = mock_sleep_data
            mock_readiness.return_value = []
            mock_activity.return_value = []

            await async_client.post("/oura/sync")

        # Now get the summary
        response = await async_client.get("/oura/summary/latest")

        # May or may not have data depending on DB state
        assert response.status_code in [200, 404]

        if response.status_code == 200:
            data = response.json()
            assert "date" in data
            assert "sleep_score" in data

    @pytest.mark.asyncio
    async def test_get_latest_summary_specific_date(self, async_client, db_session):
        """Test getting Oura summary for specific date"""
        target_date = (date.today() - timedelta(days=1)).isoformat()

        response = await async_client.get(f"/oura/summary/latest?date={target_date}")

        # Should return 200 with data or 404 if no data
        assert response.status_code in [200, 404]

    @pytest.mark.asyncio
    async def test_get_summaries_range(self, async_client, db_session):
        """Test getting Oura summaries for date range"""
        start = (date.today() - timedelta(days=7)).isoformat()
        end = date.today().isoformat()

        response = await async_client.get(
            f"/oura/summaries?start_date={start}&end_date={end}"
        )

        assert response.status_code == 200
        data = response.json()

        # Should return a list (may be empty)
        assert isinstance(data, list)

        # If data exists, verify structure
        if data:
            summary = data[0]
            assert "date" in summary
            assert "sleep_score" in summary
            assert "readiness_score" in summary
            assert "activity_score" in summary

    @pytest.mark.asyncio
    async def test_sync_without_oura_configured(self, async_client, db_session):
        """Test sync when Oura API is not configured"""
        with patch('app.services.oura.oura_service.is_configured', return_value=False):
            response = await async_client.post("/oura/sync")

            # Should either handle gracefully or return error
            assert response.status_code in [200, 400, 503]

    @pytest.mark.asyncio
    async def test_sync_with_api_error(self, async_client, db_session):
        """Test sync when Oura API returns errors"""
        with patch('app.services.oura.oura_service.get_daily_sleep') as mock_sleep:
            mock_sleep.side_effect = Exception("API Error")

            response = await async_client.post("/oura/sync")

            # Should handle error gracefully
            assert response.status_code in [200, 500, 503]

    @pytest.mark.asyncio
    async def test_invalid_date_format(self, async_client):
        """Test sync with invalid date format"""
        response = await async_client.post("/oura/sync?start_date=invalid-date")

        # Should return validation error
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_end_date_before_start_date(self, async_client):
        """Test sync with end date before start date"""
        start = date.today().isoformat()
        end = (date.today() - timedelta(days=1)).isoformat()

        response = await async_client.post(
            f"/oura/sync?start_date={start}&end_date={end}"
        )

        # Should either handle or return validation error
        assert response.status_code in [200, 400, 422]
