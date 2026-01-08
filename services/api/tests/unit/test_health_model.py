"""Unit tests for Health models"""

import pytest
from datetime import datetime, date

from app.models.health import (
    HealthMetric,
    DailySummary,
    OuraSleepData,
    OuraReadinessData,
    OuraActivityData,
)


class TestHealthMetric:
    """Test HealthMetric Pydantic model"""

    def test_health_metric_defaults(self):
        """Test HealthMetric with default values"""
        now = datetime.utcnow()
        metric = HealthMetric(
            time=now,
            metric_type="heart_rate",
            value=72.5,
        )

        assert metric.time == now
        assert metric.metric_type == "heart_rate"
        assert metric.value == 72.5
        assert metric.metadata == {}
        assert metric.source == "oura"

    def test_health_metric_custom_values(self):
        """Test HealthMetric with custom values"""
        now = datetime.utcnow()
        custom_metadata = {"quality": "high", "confidence": 0.95}
        metric = HealthMetric(
            time=now,
            metric_type="hrv",
            value=45.0,
            metadata=custom_metadata,
            source="apple_watch",
        )

        assert metric.metric_type == "hrv"
        assert metric.value == 45.0
        assert metric.metadata == custom_metadata
        assert metric.source == "apple_watch"

    def test_health_metric_various_types(self):
        """Test different metric types"""
        now = datetime.utcnow()
        metric_types = [
            ("heart_rate", 70.0),
            ("hrv", 50.0),
            ("temperature", 36.5),
            ("steps", 10000.0),
            ("calories", 2500.0),
        ]

        for metric_type, value in metric_types:
            metric = HealthMetric(
                time=now,
                metric_type=metric_type,
                value=value,
            )
            assert metric.metric_type == metric_type
            assert metric.value == value


class TestDailySummary:
    """Test DailySummary Pydantic model"""

    def test_daily_summary_defaults(self):
        """Test DailySummary with default values"""
        today = date.today()
        summary = DailySummary(date=today)

        assert summary.date == today
        assert summary.sleep_score is None
        assert summary.readiness_score is None
        assert summary.activity_score is None
        assert summary.sleep_data == {}
        assert summary.readiness_data == {}
        assert summary.activity_data == {}
        assert summary.synced_at is None

    def test_daily_summary_with_scores(self):
        """Test DailySummary with score values"""
        today = date.today()
        summary = DailySummary(
            date=today,
            sleep_score=85,
            readiness_score=78,
            activity_score=92,
        )

        assert summary.sleep_score == 85
        assert summary.readiness_score == 78
        assert summary.activity_score == 92

    def test_daily_summary_with_all_data(self):
        """Test DailySummary with all fields populated"""
        today = date.today()
        now = datetime.utcnow()
        sleep_data = {"total_sleep": 28800, "deep_sleep": 7200}
        readiness_data = {"temperature_deviation": -0.2, "resting_hr": 52}
        activity_data = {"steps": 12000, "active_calories": 650}

        summary = DailySummary(
            date=today,
            sleep_score=88,
            readiness_score=82,
            activity_score=95,
            sleep_data=sleep_data,
            readiness_data=readiness_data,
            activity_data=activity_data,
            synced_at=now,
        )

        assert summary.date == today
        assert summary.sleep_data == sleep_data
        assert summary.readiness_data == readiness_data
        assert summary.activity_data == activity_data
        assert summary.synced_at == now

    def test_daily_summary_scores_range(self):
        """Test that scores are in valid range (0-100)"""
        today = date.today()

        # Valid scores
        summary = DailySummary(
            date=today,
            sleep_score=0,
            readiness_score=50,
            activity_score=100,
        )
        assert 0 <= summary.sleep_score <= 100
        assert 0 <= summary.readiness_score <= 100
        assert 0 <= summary.activity_score <= 100


class TestOuraSleepData:
    """Test OuraSleepData Pydantic model"""

    def test_oura_sleep_data_defaults(self):
        """Test OuraSleepData with all None values"""
        sleep = OuraSleepData()

        assert sleep.score is None
        assert sleep.total_sleep_duration is None
        assert sleep.rem_sleep_duration is None
        assert sleep.deep_sleep_duration is None
        assert sleep.light_sleep_duration is None
        assert sleep.awake_time is None
        assert sleep.sleep_efficiency is None

    def test_oura_sleep_data_complete(self):
        """Test OuraSleepData with complete data"""
        bedtime_start = datetime.utcnow()
        bedtime_end = datetime.utcnow()

        sleep = OuraSleepData(
            score=85,
            total_sleep_duration=28800,  # 8 hours in seconds
            rem_sleep_duration=7200,  # 2 hours
            deep_sleep_duration=5400,  # 1.5 hours
            light_sleep_duration=14400,  # 4 hours
            awake_time=1800,  # 30 minutes
            sleep_efficiency=95,
            bedtime_start=bedtime_start,
            bedtime_end=bedtime_end,
            average_heart_rate=52.5,
            lowest_heart_rate=48,
            average_hrv=65,
        )

        assert sleep.score == 85
        assert sleep.total_sleep_duration == 28800
        assert sleep.rem_sleep_duration == 7200
        assert sleep.average_heart_rate == 52.5
        assert sleep.average_hrv == 65

    def test_oura_sleep_durations_consistency(self):
        """Test that sleep stage durations make sense"""
        sleep = OuraSleepData(
            total_sleep_duration=28800,  # 8 hours
            rem_sleep_duration=7200,  # 2 hours
            deep_sleep_duration=5400,  # 1.5 hours
            light_sleep_duration=14400,  # 4 hours
            awake_time=1800,  # 0.5 hours
        )

        # Total should approximately equal sum of stages
        stages_sum = (
            sleep.rem_sleep_duration
            + sleep.deep_sleep_duration
            + sleep.light_sleep_duration
            + sleep.awake_time
        )
        assert stages_sum == 28800


class TestOuraReadinessData:
    """Test OuraReadinessData Pydantic model"""

    def test_oura_readiness_data_defaults(self):
        """Test OuraReadinessData with defaults"""
        readiness = OuraReadinessData()

        assert readiness.score is None
        assert readiness.temperature_deviation is None
        assert readiness.resting_heart_rate is None

    def test_oura_readiness_data_complete(self):
        """Test OuraReadinessData with complete data"""
        readiness = OuraReadinessData(
            score=82,
            temperature_deviation=-0.3,
            previous_day_activity="optimal",
            sleep_balance="optimal",
            previous_night="optimal",
            activity_balance="optimal",
            resting_heart_rate=52,
            hrv_balance="optimal",
            recovery_index="optimal",
        )

        assert readiness.score == 82
        assert readiness.temperature_deviation == -0.3
        assert readiness.resting_heart_rate == 52
        assert readiness.hrv_balance == "optimal"


class TestOuraActivityData:
    """Test OuraActivityData Pydantic model"""

    def test_oura_activity_data_defaults(self):
        """Test OuraActivityData with defaults"""
        activity = OuraActivityData()

        assert activity.score is None
        assert activity.steps is None
        assert activity.active_calories is None
        assert activity.total_calories is None

    def test_oura_activity_data_complete(self):
        """Test OuraActivityData with complete data"""
        activity = OuraActivityData(
            score=92,
            steps=12500,
            active_calories=650,
            total_calories=2400,
            sedentary_time=28800,  # 8 hours
            low_activity_time=14400,  # 4 hours
            medium_activity_time=3600,  # 1 hour
            high_activity_time=1800,  # 30 minutes
            movement_every_hour=85.0,
            meet_daily_targets=95,
        )

        assert activity.score == 92
        assert activity.steps == 12500
        assert activity.active_calories == 650
        assert activity.total_calories == 2400
        assert activity.movement_every_hour == 85.0

    def test_oura_activity_time_breakdown(self):
        """Test that activity times are in seconds and make sense"""
        activity = OuraActivityData(
            sedentary_time=28800,  # 8 hours
            low_activity_time=14400,  # 4 hours
            medium_activity_time=7200,  # 2 hours
            high_activity_time=3600,  # 1 hour
        )

        # Total should be ~24 hours (86400 seconds)
        total_time = (
            activity.sedentary_time
            + activity.low_activity_time
            + activity.medium_activity_time
            + activity.high_activity_time
        )
        # Should be close to 24 hours but may not be exact
        assert 43200 <= total_time <= 86400  # Between 12 and 24 hours


class TestHealthModelIntegration:
    """Integration tests for health model relationships"""

    def test_daily_summary_with_nested_oura_data(self):
        """Test DailySummary with nested Oura data structures"""
        today = date.today()

        sleep_data = {
            "score": 85,
            "total_sleep_duration": 28800,
            "rem_sleep_duration": 7200,
        }

        readiness_data = {
            "score": 82,
            "temperature_deviation": -0.2,
            "resting_heart_rate": 52,
        }

        activity_data = {
            "score": 92,
            "steps": 12000,
            "active_calories": 650,
        }

        summary = DailySummary(
            date=today,
            sleep_score=85,
            readiness_score=82,
            activity_score=92,
            sleep_data=sleep_data,
            readiness_data=readiness_data,
            activity_data=activity_data,
        )

        # Can access nested data
        assert summary.sleep_data["total_sleep_duration"] == 28800
        assert summary.readiness_data["resting_heart_rate"] == 52
        assert summary.activity_data["steps"] == 12000

    def test_health_metrics_time_series(self):
        """Test that health metrics can form a time series"""
        base_time = datetime.utcnow()
        metrics = []

        for i in range(5):
            metric = HealthMetric(
                time=base_time,
                metric_type="heart_rate",
                value=70.0 + i,
                metadata={"sequence": i},
            )
            metrics.append(metric)

        assert len(metrics) == 5
        assert metrics[0].value == 70.0
        assert metrics[4].value == 74.0
        assert all(m.metric_type == "heart_rate" for m in metrics)
