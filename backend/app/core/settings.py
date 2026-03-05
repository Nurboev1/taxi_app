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
    sms_provider: str = "test"
    otp_ttl_minutes: int = 5
    otp_cooldown_seconds: int = 60
    eskiz_base_url: str = "https://notify.eskiz.uz"
    eskiz_email: str = ""
    eskiz_password: str = ""
    eskiz_from: str = "4546"
    eskiz_callback_url: str = ""
    eskiz_timeout_seconds: int = 10
    eskiz_test_mode: bool = False

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


settings = Settings()
