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
    fcm_server_key: str = ""
    fcm_project_id: str = ""
    fcm_service_account_file: str = ""
    sms_provider: str = "devsms"
    otp_ttl_minutes: int = 5
    otp_cooldown_seconds: int = 60
    devsms_base_url: str = "https://devsms.uz/api"
    devsms_token: str = ""
    devsms_from: str = "4546"
    devsms_timeout_seconds: int = 10

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
