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
    cors_allowed_origins: str = "https://safaruz.duckdns.org,http://localhost:3000,http://127.0.0.1:3000"
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
    auth_rate_window_seconds: int = 600
    auth_rate_request_otp_per_ip: int = 30
    auth_rate_request_otp_per_phone: int = 5
    auth_rate_complete_otp_per_ip: int = 60
    auth_rate_complete_otp_per_phone: int = 20
    auth_rate_login_password_per_ip: int = 60
    auth_rate_login_password_per_phone: int = 12
    auth_rate_support_contact_per_ip: int = 20
    sentry_dsn: str = ""
    sentry_environment: str = "production"
    sentry_traces_sample_rate: float = 0.0
    healthcheck_deep_default: bool = False
    healthcheck_fail_on_sms: bool = False
    healthcheck_fail_on_fcm: bool = False
    healthcheck_fail_on_telegram_support: bool = False
    telegram_support_bot_token: str = ""
    telegram_support_chat_id: str = ""
    telegram_support_timeout_seconds: int = 8
    telegram_support_bot_username: str = "SafarUzSupportBot"
    telegram_support_webhook_secret: str = ""
    telegram_support_delete_sensitive_messages: bool = True

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    def cors_origins(self) -> list[str]:
        raw = (self.cors_allowed_origins or "").strip()
        if not raw:
            return []
        return [part.strip() for part in raw.split(",") if part.strip()]


settings = Settings()
