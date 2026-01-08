"""Unit tests for User models"""

import pytest
from datetime import datetime, time
from uuid import uuid4

from app.models.user import (
    UserProfile,
    UserProfileUpdate,
    UserGoals,
)


class TestUserProfile:
    """Test UserProfile Pydantic model"""

    def test_user_profile_defaults(self):
        """Test UserProfile with default values"""
        user_id = uuid4()
        profile = UserProfile(id=user_id)

        assert profile.id == user_id
        assert profile.name is None
        assert profile.settings == {}
        assert profile.total_xp == 0
        assert profile.level == 1
        assert profile.target_wake_time == time(6, 0)
        assert profile.target_bedtime == time(22, 30)
        assert profile.target_screen_hours == 3.0
        assert profile.target_gym_sessions == 3

    def test_user_profile_custom_values(self):
        """Test UserProfile with custom values"""
        user_id = uuid4()
        custom_settings = {"theme": "dark", "notifications": True}
        profile = UserProfile(
            id=user_id,
            name="Test User",
            settings=custom_settings,
            total_xp=1500,
            level=5,
            target_wake_time=time(5, 30),
            target_bedtime=time(23, 0),
            target_screen_hours=2.5,
            target_gym_sessions=4,
        )

        assert profile.id == user_id
        assert profile.name == "Test User"
        assert profile.settings == custom_settings
        assert profile.total_xp == 1500
        assert profile.level == 5
        assert profile.target_wake_time == time(5, 30)
        assert profile.target_bedtime == time(23, 0)
        assert profile.target_screen_hours == 2.5
        assert profile.target_gym_sessions == 4

    def test_user_profile_with_timestamps(self):
        """Test UserProfile with timestamp values"""
        user_id = uuid4()
        now = datetime.utcnow()
        profile = UserProfile(
            id=user_id,
            created_at=now,
            updated_at=now,
        )

        assert profile.created_at == now
        assert profile.updated_at == now


class TestUserProfileUpdate:
    """Test UserProfileUpdate Pydantic model"""

    def test_user_profile_update_empty(self):
        """Test UserProfileUpdate with no values"""
        update = UserProfileUpdate()

        assert update.name is None
        assert update.settings is None
        assert update.target_wake_time is None
        assert update.target_bedtime is None
        assert update.target_screen_hours is None
        assert update.target_gym_sessions is None

    def test_user_profile_update_partial(self):
        """Test UserProfileUpdate with partial values"""
        update = UserProfileUpdate(
            name="Updated Name",
            target_wake_time=time(5, 0),
        )

        assert update.name == "Updated Name"
        assert update.target_wake_time == time(5, 0)
        assert update.settings is None
        assert update.target_bedtime is None

    def test_user_profile_update_all_fields(self):
        """Test UserProfileUpdate with all fields"""
        custom_settings = {"theme": "light"}
        update = UserProfileUpdate(
            name="Full Update",
            settings=custom_settings,
            target_wake_time=time(5, 0),
            target_bedtime=time(22, 0),
            target_screen_hours=2.0,
            target_gym_sessions=5,
        )

        assert update.name == "Full Update"
        assert update.settings == custom_settings
        assert update.target_wake_time == time(5, 0)
        assert update.target_bedtime == time(22, 0)
        assert update.target_screen_hours == 2.0
        assert update.target_gym_sessions == 5


class TestUserGoals:
    """Test UserGoals Pydantic model"""

    def test_user_goals_creation(self):
        """Test UserGoals creation with all fields"""
        goals = UserGoals(
            target_wake_time=time(6, 30),
            target_bedtime=time(22, 30),
            target_screen_hours=3.5,
            target_gym_sessions=4,
        )

        assert goals.target_wake_time == time(6, 30)
        assert goals.target_bedtime == time(22, 30)
        assert goals.target_screen_hours == 3.5
        assert goals.target_gym_sessions == 4

    def test_user_goals_all_fields_required(self):
        """Test that UserGoals requires all fields"""
        with pytest.raises(Exception):  # Pydantic ValidationError
            UserGoals(
                target_wake_time=time(6, 30),
                # Missing other required fields
            )


class TestUserModelIntegration:
    """Integration tests for user model relationships"""

    def test_settings_can_store_complex_data(self):
        """Test that settings JSONB field can store complex data"""
        user_id = uuid4()
        complex_settings = {
            "theme": "dark",
            "notifications": {
                "email": True,
                "push": False,
                "categories": ["health", "timeline"],
            },
            "preferences": {
                "language": "en",
                "timezone": "UTC",
                "units": "metric",
            },
        }

        profile = UserProfile(id=user_id, settings=complex_settings)
        assert profile.settings == complex_settings
        assert profile.settings["notifications"]["categories"] == ["health", "timeline"]

    def test_time_values_are_time_objects(self):
        """Test that time fields are proper time objects"""
        user_id = uuid4()
        profile = UserProfile(id=user_id)

        assert isinstance(profile.target_wake_time, time)
        assert isinstance(profile.target_bedtime, time)
        assert profile.target_wake_time.hour == 6
        assert profile.target_wake_time.minute == 0
        assert profile.target_bedtime.hour == 22
        assert profile.target_bedtime.minute == 30

    def test_xp_and_level_progression(self):
        """Test XP and level tracking"""
        user_id = uuid4()

        # Starting profile
        profile = UserProfile(id=user_id, total_xp=0, level=1)
        assert profile.total_xp == 0
        assert profile.level == 1

        # After gaining XP
        profile_leveled = UserProfile(id=user_id, total_xp=2000, level=3)
        assert profile_leveled.total_xp == 2000
        assert profile_leveled.level == 3

    def test_goals_realistic_ranges(self):
        """Test that goal values are realistic"""
        goals = UserGoals(
            target_wake_time=time(5, 0),  # Early riser
            target_bedtime=time(23, 30),  # Late bedtime
            target_screen_hours=1.5,  # Minimal screen time
            target_gym_sessions=7,  # Daily gym
        )

        assert goals.target_wake_time.hour >= 0
        assert goals.target_wake_time.hour < 24
        assert goals.target_bedtime.hour >= 0
        assert goals.target_bedtime.hour < 24
        assert goals.target_screen_hours > 0
        assert goals.target_gym_sessions > 0
