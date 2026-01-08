"""Stats Service configuration"""

from functools import lru_cache
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application settings"""

    # Application
    app_name: str = "Stats Service"
    environment: str = Field(default="development", alias="ENVIRONMENT")
    debug: bool = True

    # Database
    database_url: str = Field(
        default="postgresql://stats:stats_dev_password@localhost:5433/stats",
        alias="DATABASE_URL"
    )

    # MQTT
    mqtt_broker: str = Field(default="localhost", alias="MQTT_BROKER")
    mqtt_port: int = Field(default=1883, alias="MQTT_PORT")
    mqtt_topic_activities: str = "stats/activities"
    mqtt_topic_events: str = "stats/events"

    # Character XP progression
    character_level_base: int = 1000  # XP for level 2
    character_level_multiplier: float = 1.5  # Each level needs 1.5x more

    # Stat XP progression
    stat_level_base: int = 100  # XP for stat level 2
    stat_level_multiplier: float = 1.5

    # Starting values
    starting_stat_value: int = 10
    starting_stat_points: int = 0
    starting_respec_tokens: int = 1

    # Core stats
    core_stats: list[str] = ["STR", "INT", "WIS", "STA", "CHA", "LCK"]

    class Config:
        env_file = ".env"
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()


# Activity → Stat XP mapping
ACTIVITY_XP_MAPPING = {
    # Fitness activities
    "gym_session": {"STR": 75, "STA": 30},
    "strength_training": {"STR": 100, "STA": 20},
    "cardio_session": {"STA": 80, "STR": 20},
    "sports_activity": {"STR": 50, "STA": 50, "CHA": 20},
    "yoga_session": {"WIS": 40, "STA": 30, "STR": 20},

    # Sleep/Recovery
    "sleep_tracked": {"STA": 30},
    "quality_sleep": {"STA": 50, "WIS": 20},
    "excellent_sleep": {"STA": 75, "WIS": 30, "LCK": 10},
    "early_rise": {"STA": 25, "WIS": 25},

    # Mental/Learning
    "learning_session": {"INT": 60, "WIS": 20},
    "reading_session": {"INT": 40, "WIS": 30},
    "meditation": {"WIS": 50, "STA": 20},
    "problem_solved": {"INT": 80, "WIS": 40},
    "skill_practiced": {"INT": 50},

    # Work
    "work_completed": {"INT": 30},
    "project_milestone": {"INT": 60, "WIS": 30},
    "productive_day": {"INT": 40, "STA": 20},

    # Social
    "social_event": {"CHA": 60, "LCK": 20},
    "networking": {"CHA": 50, "INT": 20},
    "helped_someone": {"CHA": 40, "WIS": 30},
    "public_speaking": {"CHA": 80, "INT": 20},

    # Habits/Streaks
    "habit_completed": {"WIS": 20},
    "streak_maintained": {"WIS": 40, "STA": 20},
    "perfect_day": {"STR": 20, "INT": 20, "WIS": 20, "STA": 20, "CHA": 20, "LCK": 20},

    # Achievements
    "achievement_bronze": {"LCK": 30},
    "achievement_silver": {"LCK": 50},
    "achievement_gold": {"LCK": 80},
    "achievement_platinum": {"LCK": 120},
    "achievement_diamond": {"LCK": 200},

    # Life Score bonuses
    "life_score_70": {"WIS": 10},
    "life_score_80": {"WIS": 20, "STA": 10},
    "life_score_90": {"STR": 15, "INT": 15, "WIS": 15, "STA": 15, "CHA": 15, "LCK": 15},

    # Random/Luck
    "lucky_event": {"LCK": 50},
    "new_opportunity": {"LCK": 40, "CHA": 20},
}
