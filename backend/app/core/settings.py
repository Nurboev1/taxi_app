from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "SafarUz MVP"
    env: str = "dev"
    secret_key: str = "super-secret-key-change-me"
    access_token_expire_minutes: int = 60 * 24 * 7
    database_url: str = "postgresql+psycopg2://taxi:taxi@localhost:5432/taxi_db"
    admin_username: str = "admin"
    admin_password: str = "admin123"
    admin_token_expire_minutes: int = 60 * 12

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
