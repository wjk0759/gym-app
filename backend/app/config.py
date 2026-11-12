from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_env: str = "dev"
    # 仅开发/自动化测试可开启；生产即使误设为 dev 也应保持 false。
    allow_dev_user_header: bool = False
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
    # Agent 每一步工具决策单独控制推理强度；整周取消这类多动作请求
    # 用 max 会额外花几十秒，high 在准确率和延迟之间更稳。
    llm_agent_reasoning_effort: str = "high"
    # AI 计划生成的 reasoning 强度也单独控制；默认 low，追求更高质量可调 high。
    # 计划生成默认走 AI，再用规则校验；模型失败/超时自动回退模板。
    llm_plan_enabled: bool = True
    llm_plan_reasoning_effort: str = "low"
    # 限制单进程同时打到模型服务的请求数，避免把连接池和上游限流打满。
    llm_max_concurrency: int = 8
    llm_timeout_seconds: float = 90.0
    # 全局 token 预算。0 表示不启用；按 Asia/Shanghai 自然日/自然月统计，
    # 70%/90% 写告警日志，100% 后所有模型调用自动降级到规则/Mock。
    llm_daily_token_budget: int = 0
    llm_monthly_token_budget: int = 0
    # 计划/饮食周计划成功后的服务端冷却。自动化 smoke 可设为 0 连续验证，
    # 生产保持 60 秒；客户端也有同样的 60 秒防连点。
    generation_cooldown_seconds: int = 60
    # Coach context is serialized JSON; keep it bounded before it reaches the
    # model. 24k Chinese characters is roughly 8–12k tokens depending on JSON
    # punctuation; lower it if the provider's context window is tighter.
    coach_context_max_chars: int = 24000

    vision_model: str = ""
    vision_base_url: str = ""
    vision_api_key: str = ""

    # 视觉复核模型（当前用豆包 lite 做坐姿划船 / 腿举的二选一）。
    # 只在主视觉结果落在腿类器械时调用，避免每张图都多一次请求。
    vision_gate_enabled: bool = False
    vision_gate_base_url: str = ""
    vision_gate_model: str = ""
    vision_gate_api_key: str = ""
    vision_gate_timeout_seconds: float = 20.0

    # 认证。生产环境必须配置 JWT_SECRET；开发环境未配置时使用固定开发密钥。
    jwt_secret: str = ""
    access_token_minutes: int = 30
    refresh_token_days: int = 30
    # 同一账号最多保留的活跃设备会话。新设备登录会撤销最久未使用的一个；
    # 同设备再次登录只保留最新会话，避免重装/重复登录堆积。
    max_active_sessions_per_user: int = 5

    # Sign in with Apple 的 audience 通常是 App Bundle ID（或 Service ID）。
    apple_client_id: str = "com.wjk.fitai"
    # StoreKit 2 服务端校验：Bundle ID 与允许的订阅商品。
    app_store_bundle_id: str = "com.wjk.fitai"
    storekit_product_ids: str = "com.fitai.app.pro.monthly,com.fitai.app.pro.yearly"
    storekit_allowed_environments: str = "Production,Sandbox"
    # App Store Server API 对账。生产/预发通过环境变量注入，不要提交 p8。
    app_store_api_key_id: str = ""
    app_store_api_issuer_id: str = ""
    app_store_api_private_key: str = ""
    app_store_api_private_key_path: str = ""
    # production | sandbox；sandbox 用于 TestFlight/沙盒联调。
    app_store_api_environment: str = "production"
    # 仅供测试/私有代理覆盖；留空使用 Apple 官方地址。
    app_store_api_base_url: str = ""
    # 后台/定时任务调用 /iap/app-store/reconcile 的共享令牌。
    app_store_reconcile_token: str = ""

    # 短信：dev 返回开发验证码；webhook 把验证码 POST 给自定义短信网关；
    # aliyun_pnvs 使用阿里云号码认证服务的「短信认证」（免签名/模板，个人可用）。
    sms_provider: str = "dev"
    sms_webhook_url: str = ""
    sms_webhook_token: str = ""
    aliyun_pnvs_access_key_id: str = ""
    aliyun_pnvs_access_key_secret: str = ""
    aliyun_pnvs_sign_name: str = ""
    aliyun_pnvs_template_code: str = ""
    aliyun_pnvs_endpoint: str = "dypnsapi.aliyuncs.com"
    aliyun_pnvs_country_code: str = "86"

    # 微信/QQ OAuth。未配置时开发环境提供模拟授权页，生产环境返回未配置。
    wechat_app_id: str = ""
    wechat_app_secret: str = ""
    qq_app_id: str = ""
    qq_app_secret: str = ""
    oauth_callback_base: str = ""
    public_base_url: str = ""
    app_callback_scheme: str = "fitai"

    cors_origins: str = "*"

    @property
    def vision_model_name(self) -> str:
        """The vision model actually used: VISION_MODEL, or the LLM model."""
        return (self.vision_model or self.llm_model or "").strip()

    @property
    def use_mock_llm(self) -> bool:
        return self.llm_provider == "mock" or not self.llm_api_key

    @property
    def use_mock_vision(self) -> bool:
        return not self.vision_model_name or not (
            self.vision_api_key or self.llm_api_key
        )

    @property
    def allowed_origins(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    def validate_runtime(self) -> None:
        """Fail fast instead of booting a production server with dev defaults."""
        if self.app_env not in {"production", "prod"}:
            return
        required = {
            "JWT_SECRET": self.jwt_secret,
            "PUBLIC_BASE_URL": self.public_base_url,
            "APPLE_CLIENT_ID": self.apple_client_id,
            "APP_STORE_BUNDLE_ID": self.app_store_bundle_id,
            "STOREKIT_PRODUCT_IDS": self.storekit_product_ids,
            "LLM_API_KEY": self.llm_api_key,
        }
        missing = [name for name, value in required.items() if not value.strip()]
        if missing:
            raise RuntimeError(
                "生产环境缺少必要配置：" + ", ".join(sorted(missing))
            )
        if self.allow_dev_user_header:
            raise RuntimeError("生产环境必须设置 ALLOW_DEV_USER_HEADER=false")
        if self.sms_provider == "aliyun_pnvs":
            sms_required = {
                "ALIYUN_PNVS_ACCESS_KEY_ID": self.aliyun_pnvs_access_key_id,
                "ALIYUN_PNVS_ACCESS_KEY_SECRET": self.aliyun_pnvs_access_key_secret,
                "ALIYUN_PNVS_SIGN_NAME": self.aliyun_pnvs_sign_name,
                "ALIYUN_PNVS_TEMPLATE_CODE": self.aliyun_pnvs_template_code,
            }
            sms_missing = [
                name for name, value in sms_required.items() if not value.strip()
            ]
            if sms_missing:
                raise RuntimeError(
                    "阿里云短信认证缺少必要配置：" + ", ".join(sorted(sms_missing))
                )


settings = Settings()
