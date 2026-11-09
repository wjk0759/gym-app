from __future__ import annotations

import uuid
from datetime import date, datetime, timezone

from sqlalchemy import (
    JSON,
    Boolean,
    CheckConstraint,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from .db import Base


def new_id() -> str:
    return str(uuid.uuid4())


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    apple_sub: Mapped[str | None] = mapped_column(String(255), unique=True)
    phone: Mapped[str | None] = mapped_column(String(32), unique=True)
    username: Mapped[str | None] = mapped_column(String(50), unique=True, index=True)
    password_hash: Mapped[str | None] = mapped_column(String(255))
    wechat_openid: Mapped[str | None] = mapped_column(String(128), unique=True)
    wechat_unionid: Mapped[str | None] = mapped_column(String(128), unique=True, index=True)
    qq_openid: Mapped[str | None] = mapped_column(String(128), unique=True)
    avatar_url: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="active")
    is_test: Mapped[bool] = mapped_column(Boolean, default=False)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    profile: Mapped[Profile | None] = relationship(
        back_populates="user", cascade="all, delete-orphan", uselist=False
    )


class AuthSession(Base):
    __tablename__ = "auth_sessions"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    refresh_token_hash: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    device_name: Mapped[str | None] = mapped_column(String(120))
    device_id: Mapped[str | None] = mapped_column(String(64))
    client_type: Mapped[str] = mapped_column(String(20), default="ios")
    ip_address: Mapped[str | None] = mapped_column(String(64))
    user_agent: Mapped[str | None] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_used_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    last_touched_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    previous_refresh_token_hash: Mapped[str | None] = mapped_column(String(128))
    previous_hash_valid_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class SmsCode(Base):
    __tablename__ = "sms_codes"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    phone: Mapped[str] = mapped_column(String(32), index=True)
    purpose: Mapped[str] = mapped_column(String(20), default="login")
    code_hash: Mapped[str] = mapped_column(String(128))
    attempts: Mapped[int] = mapped_column(Integer, default=0)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class OAuthTicket(Base):
    __tablename__ = "oauth_tickets"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    provider: Mapped[str] = mapped_column(String(20))
    is_new_user: Mapped[bool] = mapped_column(Boolean, default=False)
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AuthEvent(Base):
    __tablename__ = "auth_events"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    event: Mapped[str] = mapped_column(String(40), index=True)
    method: Mapped[str] = mapped_column(String(30), default="")
    success: Mapped[bool] = mapped_column(Boolean, default=True)
    ip_address: Mapped[str | None] = mapped_column(String(64))
    user_agent: Mapped[str | None] = mapped_column(String(255))
    detail: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Profile(Base):
    __tablename__ = "profiles"

    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    nickname: Mapped[str] = mapped_column(String(50), default="")
    sex: Mapped[str] = mapped_column(String(10), default="male")
    birth_date: Mapped[date | None] = mapped_column(Date)
    height_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    weight_kg: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    body_fat_pct: Mapped[float | None] = mapped_column(Numeric(4, 1, asdecimal=False))
    chest_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    waist_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    hip_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    experience: Mapped[str] = mapped_column(String(20), default="beginner")
    # Server-owned progression tier derived from completed training days.
    # experience remains the user's self-reported starting point.
    training_stage: Mapped[str] = mapped_column(String(20), default="beginner")
    injuries: Mapped[list] = mapped_column(JSON, default=list)
    equipment: Mapped[list] = mapped_column(JSON, default=lambda: ["bodyweight"])
    weekly_days: Mapped[int] = mapped_column(Integer, default=3)
    session_minutes: Mapped[int] = mapped_column(Integer, default=45)
    onboarded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    user: Mapped[User] = relationship(back_populates="profile")

    @property
    def age(self) -> int | None:
        if not self.birth_date:
            return None
        today = date.today()
        return today.year - self.birth_date.year - (
            (today.month, today.day) < (self.birth_date.month, self.birth_date.day)
        )

    @property
    def bmi(self) -> float | None:
        if not self.height_cm or not self.weight_kg:
            return None
        h = self.height_cm / 100
        return round(self.weight_kg / (h * h), 1)


class Goal(Base):
    __tablename__ = "goals"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    type: Mapped[str] = mapped_column(String(20))
    target_weight_kg: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    target_body_fat_pct: Mapped[float | None] = mapped_column(Numeric(4, 1, asdecimal=False))
    target_waist_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    target_date: Mapped[date | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="active")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Exercise(Base):
    __tablename__ = "exercises"

    slug: Mapped[str] = mapped_column(String(60), primary_key=True)
    name_zh: Mapped[str] = mapped_column(String(80))
    name_en: Mapped[str | None] = mapped_column(String(120))
    muscle_group: Mapped[str] = mapped_column(String(20), index=True)
    equipment: Mapped[str] = mapped_column(String(20), index=True)
    is_compound: Mapped[bool] = mapped_column(Boolean, default=False)
    difficulty: Mapped[int] = mapped_column(Integer, default=1)
    instructions: Mapped[str | None] = mapped_column(Text)
    video_url: Mapped[str | None] = mapped_column(Text)
    thumbnail_url: Mapped[str | None] = mapped_column(Text)
    motion_start_url: Mapped[str | None] = mapped_column(Text)
    motion_end_url: Mapped[str | None] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    contraindications: Mapped[list] = mapped_column(JSON, default=list)
    source: Mapped[str | None] = mapped_column(String(40))
    license: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ExerciseVideo(Base):
    __tablename__ = "exercise_videos"
    __table_args__ = (
        Index("ix_exercise_videos_slug_status", "exercise_slug", "status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    exercise_slug: Mapped[str] = mapped_column(
        String(60), ForeignKey("exercises.slug", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(120))
    description: Mapped[str | None] = mapped_column(Text)
    video_url: Mapped[str] = mapped_column(Text)
    poster_url: Mapped[str | None] = mapped_column(Text)
    duration_seconds: Mapped[int | None] = mapped_column(Integer)
    source: Mapped[str | None] = mapped_column(String(80))
    license_note: Mapped[str | None] = mapped_column(String(200))
    license_expires_at: Mapped[date | None] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    version: Mapped[int] = mapped_column(Integer, default=1)
    created_by: Mapped[str | None] = mapped_column(String(40))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class ExerciseMediaAsset(Base):
    """Watch/phone derivatives of a 3D exercise animation.

    The raw 1080p source is never stored in MySQL; only URLs and metadata are
    persisted. One row represents one active derivative for an exercise/sex.
    """

    __tablename__ = "exercise_media_assets"
    __table_args__ = (
        UniqueConstraint(
            "exercise_slug",
            "variant_key",
            "version",
            name="uq_exercise_media_variant",
        ),
        Index("ix_exercise_media_slug_status", "exercise_slug", "status"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    exercise_slug: Mapped[str] = mapped_column(
        String(60), ForeignKey("exercises.slug", ondelete="CASCADE"), index=True
    )
    sex: Mapped[str] = mapped_column(String(10), default="unisex")
    variant_key: Mapped[str | None] = mapped_column(String(80))
    source_pack: Mapped[str | None] = mapped_column(String(20))
    visual_style: Mapped[str | None] = mapped_column(String(30))
    visual_priority: Mapped[int] = mapped_column(Integer, default=1)
    source: Mapped[str] = mapped_column(String(40))
    phone_url: Mapped[str] = mapped_column(Text)
    watch_url: Mapped[str] = mapped_column(Text)
    poster_url: Mapped[str | None] = mapped_column(Text)
    duration_seconds: Mapped[int | None] = mapped_column(Integer)
    loop_start_ms: Mapped[int | None] = mapped_column(Integer)
    loop_end_ms: Mapped[int | None] = mapped_column(Integer)
    watch_sha256: Mapped[str | None] = mapped_column(String(64))
    version: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    license_note: Mapped[str | None] = mapped_column(String(200))
    license_expires_at: Mapped[date | None] = mapped_column(Date)
    purchase_ref: Mapped[str | None] = mapped_column(String(120))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class Program(Base):
    __tablename__ = "programs"
    __table_args__ = (
        Index("ix_programs_user_status_version", "user_id", "status", "version"),
        Index("ix_programs_created_at", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(120))
    goal_type: Mapped[str] = mapped_column(String(20))
    version: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    start_date: Mapped[date] = mapped_column(Date, default=date.today)
    weeks: Mapped[int] = mapped_column(Integer, default=4)
    generated_by: Mapped[str] = mapped_column(String(20), default="ai")
    model_name: Mapped[str | None] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    days: Mapped[list[ProgramDay]] = relationship(
        back_populates="program",
        cascade="all, delete-orphan",
        order_by="ProgramDay.week_index, ProgramDay.weekday",
    )


class ProgramDay(Base):
    __tablename__ = "program_days"
    __table_args__ = (
        UniqueConstraint(
            "program_id",
            "week_index",
            "weekday",
            name="uq_program_days_program_week_weekday",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    program_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("programs.id", ondelete="CASCADE"), index=True
    )
    week_index: Mapped[int] = mapped_column(Integer)
    weekday: Mapped[int] = mapped_column(Integer)
    title: Mapped[str] = mapped_column(String(80))
    focus: Mapped[list] = mapped_column(JSON, default=list)

    program: Mapped[Program] = relationship(back_populates="days")
    exercises: Mapped[list[PlanExercise]] = relationship(
        back_populates="day",
        cascade="all, delete-orphan",
        order_by="PlanExercise.order_index",
    )


class PlanExercise(Base):
    __tablename__ = "plan_exercises"
    __table_args__ = (
        UniqueConstraint(
            "program_day_id",
            "order_index",
            name="uq_plan_exercises_day_order",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    program_day_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("program_days.id", ondelete="CASCADE"), index=True
    )
    exercise_slug: Mapped[str] = mapped_column(
        String(60), ForeignKey("exercises.slug"), index=True
    )
    order_index: Mapped[int] = mapped_column(Integer)
    sets: Mapped[int] = mapped_column(Integer, default=3)
    reps: Mapped[str] = mapped_column(String(20), default="10")
    weight_kg: Mapped[float | None] = mapped_column(Numeric(6, 2, asdecimal=False))
    rest_sec: Mapped[int] = mapped_column(Integer, default=60)
    rpe: Mapped[float | None] = mapped_column(Numeric(3, 1, asdecimal=False))
    notes: Mapped[str | None] = mapped_column(Text)

    day: Mapped[ProgramDay] = relationship(back_populates="exercises")
    exercise: Mapped[Exercise] = relationship(lazy="joined")


class WorkoutSession(Base):
    __tablename__ = "workout_sessions"
    __table_args__ = (
        Index("ix_workout_sessions_user_started", "user_id", "started_at"),
        Index("ix_workout_sessions_started_at", "started_at"),
        UniqueConstraint("user_id", "client_id", name="uq_workout_sessions_user_client"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    # iOS 本地训练记录 ID；用于网络重试时幂等写入，历史数据可为空。
    client_id: Mapped[str | None] = mapped_column(String(36))
    program_day_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("program_days.id", ondelete="SET NULL"), index=True
    )
    source: Mapped[str] = mapped_column(String(20), default="phone")
    healthkit_workout_id: Mapped[str | None] = mapped_column(String(64))
    revision: Mapped[int] = mapped_column(Integer, default=1)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_min: Mapped[int | None] = mapped_column(Integer)
    feeling: Mapped[int | None] = mapped_column(Integer)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    sets: Mapped[list[SetLog]] = relationship(
        back_populates="session", cascade="all, delete-orphan"
    )


class SetLog(Base):
    __tablename__ = "set_logs"
    __table_args__ = (
        UniqueConstraint(
            "session_id",
            "exercise_slug",
            "set_index",
            name="uq_set_logs_session_exercise_set",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    session_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("workout_sessions.id", ondelete="CASCADE"), index=True
    )
    exercise_slug: Mapped[str] = mapped_column(
        String(60), ForeignKey("exercises.slug")
    )
    set_index: Mapped[int] = mapped_column(Integer)
    weight_kg: Mapped[float | None] = mapped_column(Numeric(6, 2, asdecimal=False))
    reps: Mapped[int | None] = mapped_column(Integer)
    rpe: Mapped[float | None] = mapped_column(Numeric(3, 1, asdecimal=False))
    completed: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    session: Mapped[WorkoutSession] = relationship(back_populates="sets")


class NotificationSchedule(Base):
    __tablename__ = "notification_schedules"
    __table_args__ = (
        UniqueConstraint(
            "user_id",
            "weekday",
            name="uq_notification_schedules_user_weekday",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    weekday: Mapped[int] = mapped_column(Integer)
    hour: Mapped[int] = mapped_column(Integer)
    minute: Mapped[int] = mapped_column(Integer)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    timezone: Mapped[str] = mapped_column(String(50), default="Asia/Shanghai")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class ChatSession(Base):
    __tablename__ = "chat_sessions"
    __table_args__ = (
        Index("ix_chat_sessions_user_created", "user_id", "created_at"),
        Index("ix_chat_sessions_created_at", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    title: Mapped[str] = mapped_column(String(120), default="新对话")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    messages: Mapped[list[ChatMessage]] = relationship(
        back_populates="session",
        cascade="all, delete-orphan",
        order_by="ChatMessage.created_at",
    )


class ChatMessage(Base):
    __tablename__ = "chat_messages"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    session_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("chat_sessions.id", ondelete="CASCADE"), index=True
    )
    role: Mapped[str] = mapped_column(String(20))
    content: Mapped[str] = mapped_column(Text)
    citations: Mapped[list] = mapped_column(JSON, default=list)
    safety_flag: Mapped[str | None] = mapped_column(String(40))
    tokens: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    session: Mapped[ChatSession] = relationship(back_populates="messages")


class AgentRun(Base):
    __tablename__ = "agent_runs"
    __table_args__ = (
        Index("ix_agent_runs_user_created", "user_id", "created_at"),
        Index("ix_agent_runs_status_created", "status", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    session_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("chat_sessions.id", ondelete="SET NULL"), index=True
    )
    intent: Mapped[str] = mapped_column(String(40), default="coach_chat")
    status: Mapped[str] = mapped_column(String(30), default="running", index=True)
    model: Mapped[str | None] = mapped_column(String(80))
    input_text: Mapped[str] = mapped_column(Text)
    output_text: Mapped[str | None] = mapped_column(Text)
    step_count: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    steps: Mapped[list[AgentStep]] = relationship(
        back_populates="run",
        cascade="all, delete-orphan",
        order_by="AgentStep.step_index",
    )
    proposals: Mapped[list[AgentPlanProposal]] = relationship(
        back_populates="run",
        cascade="all, delete-orphan",
        order_by="AgentPlanProposal.created_at",
    )


class AgentStep(Base):
    __tablename__ = "agent_steps"
    __table_args__ = (
        UniqueConstraint("run_id", "step_index", name="uq_agent_steps_run_step"),
        Index("ix_agent_steps_run", "run_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    run_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("agent_runs.id", ondelete="CASCADE"), index=True
    )
    step_index: Mapped[int] = mapped_column(Integer)
    step_type: Mapped[str] = mapped_column(String(30))
    tool_name: Mapped[str | None] = mapped_column(String(40))
    input_json: Mapped[dict] = mapped_column(JSON, default=dict)
    output_json: Mapped[dict] = mapped_column(JSON, default=dict)
    status: Mapped[str] = mapped_column(String(20), default="ok")
    error: Mapped[str | None] = mapped_column(Text)
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    run: Mapped[AgentRun] = relationship(back_populates="steps")


class AgentPlanProposal(Base):
    __tablename__ = "agent_plan_proposals"
    __table_args__ = (
        Index("ix_agent_plan_proposals_user_status", "user_id", "status", "created_at"),
        Index("ix_agent_plan_proposals_run", "run_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    run_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("agent_runs.id", ondelete="CASCADE"), index=True
    )
    base_program_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("programs.id", ondelete="SET NULL")
    )
    base_version: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(20), default="draft", index=True)
    title: Mapped[str] = mapped_column(String(120))
    plan_data: Mapped[dict] = mapped_column(JSON, default=dict)
    diff_data: Mapped[dict] = mapped_column(JSON, default=dict)
    validation_data: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    applied_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    run: Mapped[AgentRun] = relationship(back_populates="proposals")


class AgentActionEvent(Base):
    __tablename__ = "agent_action_events"
    __table_args__ = (
        UniqueConstraint("user_id", "action_id", name="uq_agent_action_events_user_action"),
        Index("ix_agent_action_events_user_created", "user_id", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    run_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("agent_runs.id", ondelete="SET NULL"), index=True
    )
    action_id: Mapped[str] = mapped_column(String(64))
    action_type: Mapped[str] = mapped_column(String(40))
    status: Mapped[str] = mapped_column(String(20), default="executed")
    message: Mapped[str | None] = mapped_column(Text)
    detail: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class PlanDayState(Base):
    """Cross-device state for a local or server plan day.

    ``plan_id`` and ``day_id`` are deliberately not foreign keys: iOS can
    generate a plan locally before the server owns it, while a server-generated
    plan uses the same UUIDs on every device. The user_id boundary is enforced.
    """

    __tablename__ = "plan_day_states"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "plan_id", "day_id", name="uq_plan_day_states_user_plan_day"
        ),
        Index("ix_plan_day_states_user_plan", "user_id", "plan_id"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    plan_id: Mapped[str] = mapped_column(String(36))
    day_id: Mapped[str] = mapped_column(String(36))
    plan_version: Mapped[int | None] = mapped_column(Integer)
    assigned_date: Mapped[date | None] = mapped_column(Date)
    skipped_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    # Client-authored timestamp used for last-write-wins conflict resolution.
    client_updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    # Server-authored timestamp used for observability and incremental reads.
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class EquipmentScan(Base):
    __tablename__ = "equipment_scans"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    image_url: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    result: Mapped[list] = mapped_column(JSON, default=list)
    model: Mapped[str | None] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AIJob(Base):
    __tablename__ = "ai_jobs"
    __table_args__ = (Index("ix_ai_jobs_created_at", "created_at"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="SET NULL"), index=True
    )
    kind: Mapped[str] = mapped_column(String(30))
    model: Mapped[str | None] = mapped_column(String(80))
    prompt_version: Mapped[str | None] = mapped_column(String(30))
    input_tokens: Mapped[int | None] = mapped_column(Integer)
    output_tokens: Mapped[int | None] = mapped_column(Integer)
    latency_ms: Mapped[int | None] = mapped_column(Integer)
    status: Mapped[str] = mapped_column(String(20), default="ok")
    error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class AIMemory(Base):
    __tablename__ = "ai_memories"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    kind: Mapped[str] = mapped_column(String(30))
    memory_key: Mapped[str] = mapped_column(String(80), default="general", index=True)
    content: Mapped[str] = mapped_column(Text)
    source: Mapped[str] = mapped_column(String(40), default="agent")
    confidence: Mapped[float] = mapped_column(Float, default=1.0)
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class FoodLog(Base):
    __tablename__ = "food_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_food_logs_user_client"),
        Index("ix_food_logs_user_logged", "user_id", "logged_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    client_id: Mapped[str] = mapped_column(String(36))
    logged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    meal: Mapped[str] = mapped_column(String(20))
    food_name: Mapped[str] = mapped_column(String(120))
    grams: Mapped[float] = mapped_column(Numeric(7, 1, asdecimal=False), default=0)
    kcal: Mapped[float] = mapped_column(Numeric(7, 1, asdecimal=False), default=0)
    protein: Mapped[float] = mapped_column(Numeric(6, 1, asdecimal=False), default=0)
    carbs: Mapped[float] = mapped_column(Numeric(6, 1, asdecimal=False), default=0)
    fat: Mapped[float] = mapped_column(Numeric(6, 1, asdecimal=False), default=0)
    fiber: Mapped[float] = mapped_column(Numeric(6, 1, asdecimal=False), default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class BodyMetric(Base):
    __tablename__ = "body_metrics"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_body_metrics_user_client"),
        Index("ix_body_metrics_user_measured", "user_id", "measured_at"),
        CheckConstraint(
            "weight_kg IS NOT NULL OR body_fat_pct IS NOT NULL "
            "OR waist_cm IS NOT NULL OR arm_cm IS NOT NULL "
            "OR thigh_cm IS NOT NULL",
            name="ck_body_metrics_any_measure",
        ),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    client_id: Mapped[str] = mapped_column(String(36))
    measured_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    weight_kg: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    body_fat_pct: Mapped[float | None] = mapped_column(Numeric(4, 1, asdecimal=False))
    waist_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    arm_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    thigh_cm: Mapped[float | None] = mapped_column(Numeric(5, 1, asdecimal=False))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class EquipmentLibraryItem(Base):
    __tablename__ = "equipment_library"
    __table_args__ = (
        UniqueConstraint("user_id", "client_id", name="uq_equipment_library_user_client"),
        Index("ix_equipment_library_user_created", "user_id", "created_at"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    client_id: Mapped[str] = mapped_column(String(36))
    name: Mapped[str] = mapped_column(String(120))
    slug: Mapped[str | None] = mapped_column(String(80))
    muscle: Mapped[str | None] = mapped_column(String(30))
    equipment: Mapped[str | None] = mapped_column(String(30))
    notes: Mapped[str] = mapped_column(Text, default="")
    source: Mapped[str] = mapped_column(String(20), default="manual")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class MealPlan(Base):
    __tablename__ = "meal_plans"
    __table_args__ = (
        UniqueConstraint("user_id", "plan_date", name="uq_meal_plans_user_date"),
        Index("ix_meal_plans_user_date", "user_id", "plan_date"),
    )

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    plan_date: Mapped[date] = mapped_column(Date)
    week_start: Mapped[date | None] = mapped_column(Date)
    strategy: Mapped[str | None] = mapped_column(String(30))
    generated_by: Mapped[str | None] = mapped_column(String(20))
    model_name: Mapped[str | None] = mapped_column(String(80))
    target_kcal: Mapped[int | None] = mapped_column(Integer)
    target_protein_g: Mapped[float | None] = mapped_column(Numeric(6, 1, asdecimal=False))
    target_carb_g: Mapped[float | None] = mapped_column(Numeric(6, 1, asdecimal=False))
    target_fat_g: Mapped[float | None] = mapped_column(Numeric(6, 1, asdecimal=False))
    plan: Mapped[dict] = mapped_column(JSON, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

class UserEntitlement(Base):
    __tablename__ = "user_entitlements"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), index=True
    )
    plan_code: Mapped[str] = mapped_column(String(20), default="pro")
    source: Mapped[str] = mapped_column(String(20))
    source_ref: Mapped[str | None] = mapped_column(String(128))
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    granted_by: Mapped[str | None] = mapped_column(String(36))
    reason: Mapped[str | None] = mapped_column(String(200))
    metadata_json: Mapped[dict | None] = mapped_column("metadata", JSON)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )

    __table_args__ = (
        UniqueConstraint("source", "source_ref", name="uk_user_entitlements_source_ref"),
        Index("ix_user_entitlements_user_expiry", "user_id", "expires_at"),
    )


class FeatureTrial(Base):
    __tablename__ = "feature_trials"

    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    feature_key: Mapped[str] = mapped_column(String(40), primary_key=True)
    source: Mapped[str] = mapped_column(String(20))
    used_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    valid_until: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    result_ref: Mapped[str | None] = mapped_column(String(80))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class FeatureUsage(Base):
    __tablename__ = "feature_usage"

    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    feature_key: Mapped[str] = mapped_column(String(40), primary_key=True)
    period_start: Mapped[date] = mapped_column(Date, primary_key=True)
    used_count: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class FeatureGenerationState(Base):
    __tablename__ = "feature_generation_state"

    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    feature_key: Mapped[str] = mapped_column(String(40), primary_key=True)
    state: Mapped[str] = mapped_column(String(12), default="running")
    cooldown_seconds: Mapped[int] = mapped_column(Integer, default=60)
    last_generated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )
    last_result_ref: Mapped[str | None] = mapped_column(String(80))
    last_idempotency_key: Mapped[str | None] = mapped_column(String(64))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )


class FeatureResultCache(Base):
    """Short-lived sanitized result for photo analysis idempotent replays.

    Only text/JSON results are stored here. Original images must never be
    persisted for replay because they contain sensitive body/meal data.
    """

    __tablename__ = "feature_result_cache"
    __table_args__ = (Index("ix_feature_result_cache_expires", "expires_at"),)

    user_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("users.id", ondelete="CASCADE"), primary_key=True
    )
    feature_key: Mapped[str] = mapped_column(String(40), primary_key=True)
    idempotency_key: Mapped[str] = mapped_column(String(64), primary_key=True)
    result: Mapped[dict] = mapped_column(JSON)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class RateLimitBucket(Base):
    __tablename__ = "rate_limit_buckets"
    __table_args__ = (Index("ix_rate_limit_buckets_updated", "updated_at"),)

    bucket_key: Mapped[str] = mapped_column(String(120), primary_key=True)
    tokens_milli: Mapped[int] = mapped_column(Integer)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow
    )


class AIRuntimeControl(Base):
    __tablename__ = "ai_runtime_control"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, default=1)
    enabled: Mapped[bool] = mapped_column(Boolean, default=True)
    reason: Mapped[str | None] = mapped_column(String(200))
    updated_by: Mapped[str | None] = mapped_column(String(36))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=utcnow, onupdate=utcnow
    )
