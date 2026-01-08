"""Application configuration using pydantic-settings"""

from functools import lru_cache
from pydantic_settings import BaseSettings
from pydantic import Field


class Settings(BaseSettings):
    """Application settings loaded from environment variables"""

    # Application
    app_name: str = "LifeOps API"
    environment: str = Field(default="development", alias="ENVIRONMENT")
    debug: bool = Field(default=True)

    # Database
    database_url: str = Field(
        default="postgresql://lifeops:lifeops_dev_password@localhost:5432/lifeops",
        alias="DATABASE_URL"
    )

    # MQTT
    mqtt_broker: str = Field(default="localhost", alias="MQTT_BROKER")
    mqtt_port: int = Field(default=1883, alias="MQTT_PORT")

    # Oura API
    oura_access_token: str | None = Field(default=None, alias="OURA_ACCESS_TOKEN")
    oura_client_id: str | None = Field(default=None, alias="OURA_CLIENT_ID")
    oura_client_secret: str | None = Field(default=None, alias="OURA_CLIENT_SECRET")
    oura_api_base_url: str = "https://api.ouraring.com/v2"

    # Security - JWT Configuration
    # IMPORTANT: Change JWT_SECRET in production to a strong random string!
    # Generate with: openssl rand -hex 32
    jwt_secret: str = Field(
        default="dev_secret_change_me_in_production",
        alias="JWT_SECRET",
        description="Secret key for JWT token signing. Must be kept secret!"
    )
    jwt_algorithm: str = Field(
        default="HS256",
        alias="JWT_ALGORITHM",
        description="Algorithm for JWT signing (HS256 or RS256)"
    )
    # Token expiration times
    access_token_expire_minutes: int = Field(
        default=15,
        alias="ACCESS_TOKEN_EXPIRE_MINUTES",
        description="Access token expiration time in minutes"
    )
    refresh_token_expire_days: int = Field(
        default=7,
        alias="REFRESH_TOKEN_EXPIRE_DAYS",
        description="Refresh token expiration time in days"
    )

    # Gamification weights
    sleep_weight: float = 0.40
    activity_weight: float = 0.25
    worklife_weight: float = 0.20
    habits_weight: float = 0.15

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        extra = "ignore"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance"""
    return Settings()


settings = get_settings()
