from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    # Database
    POSTGRES_USER: str = "ecopulse_user"
    POSTGRES_PASSWORD: str = "ecopulse_pass"
    POSTGRES_DB: str = "ecopulse_db"
    DATABASE_URL: str = "postgresql+asyncpg://ecopulse_user:ecopulse_pass@localhost:5432/ecopulse_db"
    
    # RabbitMQ
    RABBITMQ_URL: str = "amqp://guest:guest@localhost:5672/"
    
    # Redis
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Security
    JWT_SECRET: str = "super_secret_key_change_in_production"
    JWT_REFRESH_SECRET: str = "super_secret_refresh_key_change_in_production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7
    
    model_config = SettingsConfigDict(env_file="../../.env", env_file_encoding="utf-8", extra="ignore")

settings = Settings()
