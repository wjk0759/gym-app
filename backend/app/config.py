from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    database_url: str = "sqlite:///./fitai.db"
    # 后台上传的视频/封面。生产环境建议指向独立数据盘，或替换为 OSS/COS + CDN。
    media_root: str = "media"

    # mock | deepseek | qwen | doubao
    # 默认接入 DeepSeek；未配置 LLM_API_KEY 时自动回退到本地 Mock/规则。
    llm_provider: str = "deepseek"
    llm_api_key: str = ""
    llm_base_url: str = "https://api.deepseek.com/v1"
    llm_model: str = "deepseek-chat"

    vision_model: str = ""
    vision_base_url: str = ""
    vision_api_key: str = ""

    meituan_deeplink_base: str = ""
    meituan_h5_base: str = ""

    # 后台管理。生产环境必须通过 ADMIN_TOKEN 覆盖；开发环境未配置时使用 dev-admin-token。
    admin_token: str = ""

    # 认证。生产环境必须配置 JWT_SECRET；开发环境未配置时使用固定开发密钥。
    jwt_secret: str = ""
    access_token_minutes: int = 30
    refresh_token_days: int = 30

    # Sign in with Apple 的 audience 通常是 App Bundle ID（或 Service ID）。
    apple_client_id: str = "com.fitai.app"

    # 短信：dev 返回开发验证码；webhook 把验证码 POST 给自定义短信网关。
    sms_provider: str = "dev"
    sms_webhook_url: str = ""
    sms_webhook_token: str = ""

    # 微信/QQ OAuth。未配置时开发环境提供模拟授权页，生产环境返回未配置。
    wechat_app_id: str = ""
    wechat_app_secret: str = ""
    qq_app_id: str = ""
    qq_app_secret: str = ""
    oauth_callback_base: str = ""
    app_callback_scheme: str = "fitai"

    cors_origins: str = "*"

    @property
    def use_mock_llm(self) -> bool:
        return self.llm_provider == "mock" or not self.llm_api_key

    @property
    def use_mock_vision(self) -> bool:
        return not self.vision_model or not self.vision_api_key

    @property
    def allowed_origins(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


settings = Settings()
