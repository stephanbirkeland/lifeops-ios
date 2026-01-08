"""Unit tests for Oura service"""

import pytest
from datetime import date, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
import httpx

from app.services.oura import OuraService


class TestOuraService:
    """Test suite for OuraService"""

    @pytest.fixture
    def mock_access_token(self):
        return "test_token_12345"

    @pytest.fixture
    def oura_service(self, mock_access_token):
        with patch('app.services.oura.settings') as mock_settings:
            mock_settings.oura_access_token = mock_access_token
            mock_settings.oura_api_base_url = "https://api.ouraring.com/v2"
            service = OuraService(access_token=mock_access_token)
            yield service

    # ===========================================
    # Initialization Tests
    # ===========================================

    def test_init_with_token(self, mock_access_token):
        """Test service initialization with access token"""
        service = OuraService(access_token=mock_access_token)
        assert service.access_token == mock_access_token
        assert service.is_configured() is True

    def test_init_without_token(self):
        """Test service initialization without access token"""
        with patch('app.services.oura.settings') as mock_settings:
            mock_settings.oura_access_token = None
            service = OuraService()
            assert service.is_configured() is False

    def test_get_headers(self, oura_service, mock_access_token):
        """Test authorization headers generation"""
        headers = oura_service._get_headers()
        assert headers["Authorization"] == f"Bearer {mock_access_token}"
        assert headers["Content-Type"] == "application/json"

    # ===========================================
    # API Endpoint Tests - Daily Sleep
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_daily_sleep_success(self, oura_service):
        """Test fetching daily sleep data successfully"""
        start = date(2026, 1, 1)
        end = date(2026, 1, 7)

        mock_response = {
            "data": [
                {"day": "2026-01-01", "score": 85, "total_sleep_duration": 28800},
                {"day": "2026-01-02", "score": 90, "total_sleep_duration": 29700}
            ]
        }

        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.return_value = AsyncMock(
                status_code=200,
                json=lambda: mock_response
            )
            mock_get.return_value.raise_for_status = MagicMock()

            result = await oura_service.get_daily_sleep(start, end)

            assert len(result) == 2
            assert result[0]["score"] == 85
            assert result[1]["score"] == 90
            mock_get.assert_called_once()

    @pytest.mark.asyncio
    async def test_get_daily_sleep_not_configured(self):
        """Test daily sleep fetch when service not configured"""
        with patch('app.services.oura.settings') as mock_settings:
            mock_settings.oura_access_token = None
            service = OuraService()

            result = await service.get_daily_sleep(date.today())
            assert result == []

    @pytest.mark.asyncio
    async def test_get_daily_sleep_http_error(self, oura_service):
        """Test daily sleep fetch with HTTP error"""
        with patch.object(oura_service.client, 'get') as mock_get:
            mock_response = AsyncMock()
            mock_response.status_code = 401
            mock_response.text = "Unauthorized"
            mock_response.raise_for_status.side_effect = httpx.HTTPStatusError(
                "Unauthorized", request=MagicMock(), response=mock_response
            )
            mock_get.return_value = mock_response

            result = await oura_service.get_daily_sleep(date.today())
            assert result == []

    @pytest.mark.asyncio
    async def test_get_daily_sleep_network_error(self, oura_service):
        """Test daily sleep fetch with network error"""
        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.side_effect = httpx.ConnectError("Connection failed")

            result = await oura_service.get_daily_sleep(date.today())
            assert result == []

    # ===========================================
    # API Endpoint Tests - Daily Readiness
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_daily_readiness_success(self, oura_service):
        """Test fetching daily readiness data successfully"""
        start = date(2026, 1, 1)

        mock_response = {
            "data": [
                {"day": "2026-01-01", "score": 75}
            ]
        }

        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.return_value = AsyncMock(
                status_code=200,
                json=lambda: mock_response
            )
            mock_get.return_value.raise_for_status = MagicMock()

            result = await oura_service.get_daily_readiness(start)

            assert len(result) == 1
            assert result[0]["score"] == 75

    # ===========================================
    # API Endpoint Tests - Daily Activity
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_daily_activity_success(self, oura_service):
        """Test fetching daily activity data successfully"""
        start = date(2026, 1, 1)

        mock_response = {
            "data": [
                {"day": "2026-01-01", "score": 80, "steps": 8500}
            ]
        }

        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.return_value = AsyncMock(
                status_code=200,
                json=lambda: mock_response
            )
            mock_get.return_value.raise_for_status = MagicMock()

            result = await oura_service.get_daily_activity(start)

            assert len(result) == 1
            assert result[0]["steps"] == 8500

    # ===========================================
    # API Endpoint Tests - Sleep Sessions
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_sleep_sessions_success(self, oura_service):
        """Test fetching sleep sessions successfully"""
        start = date(2026, 1, 1)

        mock_response = {
            "data": [
                {"id": "session1", "type": "long_sleep", "total_duration": 28800}
            ]
        }

        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.return_value = AsyncMock(
                status_code=200,
                json=lambda: mock_response
            )
            mock_get.return_value.raise_for_status = MagicMock()

            result = await oura_service.get_sleep_sessions(start)

            assert len(result) == 1
            assert result[0]["type"] == "long_sleep"

    # ===========================================
    # API Endpoint Tests - Heart Rate
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_heart_rate_success(self, oura_service):
        """Test fetching heart rate data successfully"""
        start = datetime(2026, 1, 1, 0, 0)

        mock_response = {
            "data": [
                {"timestamp": "2026-01-01T00:00:00Z", "bpm": 60}
            ]
        }

        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.return_value = AsyncMock(
                status_code=200,
                json=lambda: mock_response
            )
            mock_get.return_value.raise_for_status = MagicMock()

            result = await oura_service.get_heart_rate(start)

            assert len(result) == 1
            assert result[0]["bpm"] == 60

    # ===========================================
    # API Endpoint Tests - Personal Info
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_personal_info_success(self, oura_service):
        """Test fetching personal info successfully"""
        mock_response = {
            "id": "user123",
            "age": 35,
            "weight": 80.5,
            "height": 180
        }

        with patch.object(oura_service.client, 'get') as mock_get:
            mock_get.return_value = AsyncMock(
                status_code=200,
                json=lambda: mock_response
            )
            mock_get.return_value.raise_for_status = MagicMock()

            result = await oura_service.get_personal_info()

            assert result["id"] == "user123"
            assert result["age"] == 35

    @pytest.mark.asyncio
    async def test_get_personal_info_not_configured(self):
        """Test personal info fetch when service not configured"""
        with patch('app.services.oura.settings') as mock_settings:
            mock_settings.oura_access_token = None
            service = OuraService()

            result = await service.get_personal_info()
            assert result is None

    # ===========================================
    # Data Sync Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_sync_daily_data_success(self, oura_service, mock_db_session):
        """Test syncing daily data to database"""
        start = date(2026, 1, 1)
        end = date(2026, 1, 2)

        # Mock API responses
        sleep_data = [
            {"day": "2026-01-01", "score": 85},
            {"day": "2026-01-02", "score": 90}
        ]
        readiness_data = [
            {"day": "2026-01-01", "score": 75},
            {"day": "2026-01-02", "score": 80}
        ]
        activity_data = [
            {"day": "2026-01-01", "score": 70},
            {"day": "2026-01-02", "score": 85}
        ]

        with patch.object(oura_service, 'get_daily_sleep', return_value=sleep_data), \
             patch.object(oura_service, 'get_daily_readiness', return_value=readiness_data), \
             patch.object(oura_service, 'get_daily_activity', return_value=activity_data):

            result = await oura_service.sync_daily_data(mock_db_session, start, end)

            assert result["sleep"] == 2
            assert result["readiness"] == 2
            assert result["activity"] == 2

    @pytest.mark.asyncio
    async def test_sync_daily_data_default_dates(self, oura_service, mock_db_session):
        """Test sync with default dates (last 7 days)"""
        with patch.object(oura_service, 'get_daily_sleep', return_value=[]), \
             patch.object(oura_service, 'get_daily_readiness', return_value=[]), \
             patch.object(oura_service, 'get_daily_activity', return_value=[]):

            result = await oura_service.sync_daily_data(mock_db_session)

            assert result["sleep"] == 0
            assert result["readiness"] == 0
            assert result["activity"] == 0

    @pytest.mark.asyncio
    async def test_sync_daily_data_partial_data(self, oura_service, mock_db_session):
        """Test sync with missing data for some metrics"""
        start = date(2026, 1, 1)

        # Only sleep data available
        sleep_data = [{"day": "2026-01-01", "score": 85}]

        with patch.object(oura_service, 'get_daily_sleep', return_value=sleep_data), \
             patch.object(oura_service, 'get_daily_readiness', return_value=[]), \
             patch.object(oura_service, 'get_daily_activity', return_value=[]):

            result = await oura_service.sync_daily_data(mock_db_session, start, start)

            assert result["sleep"] == 1
            assert result["readiness"] == 0
            assert result["activity"] == 0

    # ===========================================
    # Database Query Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_get_latest_summary_found(self, oura_service, mock_db_session):
        """Test getting latest summary when data exists"""
        target_date = date(2026, 1, 1)

        # Mock database response
        mock_row = MagicMock()
        mock_row.date = target_date
        mock_row.sleep_score = 85
        mock_row.readiness_score = 75
        mock_row.activity_score = 80
        mock_row.sleep_data = {"duration": 28800}
        mock_row.readiness_data = {}
        mock_row.activity_data = {"steps": 8500}
        mock_row.synced_at = datetime.utcnow()

        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = mock_row
        mock_db_session.execute.return_value = mock_result

        result = await oura_service.get_latest_summary(mock_db_session, target_date)

        assert result is not None
        assert result["date"] == target_date
        assert result["sleep_score"] == 85
        assert result["activity_data"]["steps"] == 8500

    @pytest.mark.asyncio
    async def test_get_latest_summary_not_found(self, oura_service, mock_db_session):
        """Test getting latest summary when no data exists"""
        mock_result = AsyncMock()
        mock_result.scalar_one_or_none.return_value = None
        mock_db_session.execute.return_value = mock_result

        result = await oura_service.get_latest_summary(mock_db_session)

        assert result is None

    @pytest.mark.asyncio
    async def test_get_summaries_range(self, oura_service, mock_db_session):
        """Test getting summaries for date range"""
        start = date(2026, 1, 1)
        end = date(2026, 1, 3)

        # Mock multiple rows
        mock_rows = []
        for i in range(3):
            row = MagicMock()
            row.date = start + timedelta(days=i)
            row.sleep_score = 80 + i
            row.readiness_score = 70 + i
            row.activity_score = 75 + i
            mock_rows.append(row)

        mock_result = AsyncMock()
        mock_result.scalars.return_value.all.return_value = mock_rows
        mock_db_session.execute.return_value = mock_result

        result = await oura_service.get_summaries_range(mock_db_session, start, end)

        assert len(result) == 3
        assert result[0]["sleep_score"] == 80
        assert result[2]["activity_score"] == 77

    # ===========================================
    # Cleanup Tests
    # ===========================================

    @pytest.mark.asyncio
    async def test_close_client(self, oura_service):
        """Test closing HTTP client"""
        with patch.object(oura_service.client, 'aclose') as mock_close:
            await oura_service.close()
            mock_close.assert_called_once()
