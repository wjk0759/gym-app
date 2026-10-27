from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    database_url: str = "sqlite:///./fitai.db"
    # 连接池/线程池。生产 MySQL 建议按机器规格调大，并在部署层开多个 worker。
    db_pool_size: int = 20
    db_max_overflow: int = 20
    db_pool_timeout: int = 30
    db_pool_recycle: int = 1800
    thread_pool_size: int = 64
    # 后台上传的视频/封面。生产环境建议指向独立数据盘，或替换为 OSS/COS + CDN。
    media_root: str = "media"

    # mock | deepseek | qwen | doubao
    # 默认接入 DeepSeek；未配置 LLM_API_KEY 时自动回退到本地 Mock/规则。
    llm_provider: str = "deepseek"
    llm_api_key: str = ""
    llm_base_url: str = "https://api.deepseek.com/v1"
    # DeepSeek-V4.1-Flash-1017：当前最新 API Flash，支持文本与视觉；
    # 复杂计划如后续需要更高质量，可切换为 deepseek-v4-pro。
    llm_model: str = "deepseek-flash"
    # low | high | max；教练 Agent 默认使用 high，兼顾质量和延迟。
    llm_reasoning_effort: str = "high"
    # 限制单进程同时打到模型服务的请求数，避免把连接池和上游限流打满。
    llm_max_concurrency: int = 8
    llm_timeout_seconds: float = 90.0

    vision_model: str = ""
    vision_base_url: str = ""
    vision_api_key: str = ""

    meituan_deeplink_base: str = ""
    meituan_h5_base: str = ""

    # 后台管理。生产环境必须通过 ADMIN_TOKEN 覆盖；开发环境未配置时使用 dev-admin-token。
    admin_token: str = ""
    # Spring Boot 管理端签发的短期 JWT；与 admin-server 的 FITAI_JWT_SECRET 保持一致。
    admin_jwt_secret: str = ""
    admin_jwt_issuer: str = "fitai-admin"

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
