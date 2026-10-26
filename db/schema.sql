-- [2026-10] Legacy PostgreSQL schema retained for historical reference.
-- MySQL is now the shared database; the authoritative MySQL schema is:
--   admin-server/src/main/resources/db/migration/V1__fitai_app_schema.sql
--   admin-server/src/main/resources/db/migration/V2__admin_console.sql

-- ============================================================
-- FitAI / 练途 · PostgreSQL 16 建表脚本
-- 说明：
--   1. 生产环境使用 PostgreSQL 16 + pgvector
--   2. 开发环境后端默认使用 SQLite（模型自动建表），本脚本是规范来源
--   3. weekday 约定：1=周一 ... 7=周日
--   4. 所有时间使用 timestamptz（UTC 存储，客户端展示本地时间）
--   5. 软删除只用于 user；其余随用户级联删除
-- ============================================================

create extension if not exists pgcrypto;
create extension if not exists vector;

-- ---------- 用户 ----------
create table users (
    id             uuid primary key default gen_random_uuid(),
    apple_sub      text unique,
    phone          text unique,
    username       text unique,
    password_hash  text,
    wechat_openid  text unique,
    wechat_unionid text unique,
    qq_openid      text unique,
    avatar_url     text,
    status         text not null default 'active'
                   check (status in ('active', 'suspended', 'deleted')),
    last_login_at  timestamptz,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now(),
    deleted_at     timestamptz
);

create index users_wechat_unionid_idx on users (wechat_unionid);

-- ---------- 认证 ----------
create table auth_sessions (
    id                 uuid primary key default gen_random_uuid(),
    user_id            uuid not null references users(id) on delete cascade,
    refresh_token_hash text not null unique,
    device_name        text,
    ip_address         text,
    user_agent         text,
    created_at         timestamptz not null default now(),
    last_used_at       timestamptz not null default now(),
    expires_at         timestamptz not null,
    revoked_at         timestamptz
);

create index auth_sessions_user_idx on auth_sessions (user_id, last_used_at desc);

create table sms_codes (
    id         uuid primary key default gen_random_uuid(),
    phone      text not null,
    purpose    text not null default 'login',
    code_hash  text not null,
    attempts   integer not null default 0,
    used_at    timestamptz,
    expires_at timestamptz not null,
    created_at timestamptz not null default now()
);

create index sms_codes_phone_idx on sms_codes (phone, created_at desc);

create table oauth_tickets (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references users(id) on delete cascade,
    provider     text not null,
    is_new_user  boolean not null default false,
    used_at      timestamptz,
    expires_at   timestamptz not null,
    created_at   timestamptz not null default now()
);

create index oauth_tickets_user_idx on oauth_tickets (user_id, created_at desc);

create table auth_events (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid references users(id) on delete set null,
    event      text not null,
    method     text not null default '',
    success    boolean not null default true,
    ip_address text,
    user_agent text,
    detail     jsonb not null default '{}',
    created_at timestamptz not null default now()
);

create index auth_events_user_idx on auth_events (user_id, created_at desc);
create index auth_events_event_idx on auth_events (event, created_at desc);

-- ---------- 档案 ----------
create table profiles (
    user_id         uuid primary key references users(id) on delete cascade,
    nickname        text not null default '',
    sex             text not null check (sex in ('male', 'female', 'other')),
    birth_date      date,
    height_cm       numeric(5,1) check (height_cm between 100 and 250),
    weight_kg       numeric(5,1) check (weight_kg between 25 and 300),
    body_fat_pct    numeric(4,1) check (body_fat_pct between 3 and 60),
    chest_cm        numeric(5,1),
    waist_cm        numeric(5,1),
    hip_cm          numeric(5,1),
    experience      text not null default 'beginner'
                    check (experience in ('beginner', 'intermediate', 'advanced')),
    injuries        text[] not null default '{}',
    equipment       text[] not null default '{bodyweight}',
    weekly_days     smallint not null default 3 check (weekly_days between 1 and 7),
    session_minutes smallint not null default 45 check (session_minutes between 15 and 180),
    onboarded_at    timestamptz,
    updated_at      timestamptz not null default now()
);

-- ---------- 目标 ----------
create table goals (
    id                  uuid primary key default gen_random_uuid(),
    user_id             uuid not null references users(id) on delete cascade,
    type                text not null
                        check (type in ('lose_fat', 'build_muscle', 'recomp', 'endurance')),
    target_weight_kg    numeric(5,1),
    target_body_fat_pct numeric(4,1),
    target_waist_cm     numeric(5,1),
    target_date         date,
    status              text not null default 'active'
                        check (status in ('active', 'achieved', 'abandoned')),
    created_at          timestamptz not null default now()
);

create unique index goals_one_active_per_user
    on goals (user_id) where status = 'active';

-- ---------- 动作库 ----------
create table exercises (
    slug              text primary key,
    name_zh           text not null,
    name_en           text,
    muscle_group      text not null
                      check (muscle_group in ('chest','back','legs','glutes','shoulders','arms','core','cardio')),
    equipment         text not null
                      check (equipment in ('bodyweight','dumbbell','barbell','machine','cable','band','kettlebell')),
    is_compound       boolean not null default false,
    difficulty        smallint not null default 1 check (difficulty between 1 and 3),
    instructions      text,
    video_url         text,
    thumbnail_url     text,
    contraindications text[] not null default '{}',
    source            text,
    license           text,
    created_at        timestamptz not null default now()
);

create index exercises_muscle_idx on exercises (muscle_group, equipment);

-- ---------- 计划（版本化） ----------
create table programs (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references users(id) on delete cascade,
    title        text not null,
    goal_type    text not null,
    version      integer not null default 1,
    status       text not null default 'active'
                 check (status in ('draft', 'active', 'archived')),
    start_date   date not null default current_date,
    weeks        smallint not null default 4 check (weeks between 1 and 12),
    generated_by text not null default 'ai' check (generated_by in ('ai', 'template', 'user')),
    model_name   text,
    created_at   timestamptz not null default now(),
    unique (user_id, version)
);

create unique index programs_one_active_per_user
    on programs (user_id) where status = 'active';

create table program_days (
    id         uuid primary key default gen_random_uuid(),
    program_id uuid not null references programs(id) on delete cascade,
    week_index smallint not null check (week_index between 1 and 12),
    weekday    smallint not null check (weekday between 1 and 7),
    title      text not null,
    focus      text[] not null default '{}',
    unique (program_id, week_index, weekday)
);

create table plan_exercises (
    id              uuid primary key default gen_random_uuid(),
    program_day_id  uuid not null references program_days(id) on delete cascade,
    exercise_slug   text not null references exercises(slug),
    order_index     smallint not null,
    sets            smallint not null check (sets between 1 and 10),
    reps            text not null,                    -- 支持 "8-10" / "12" / "30s"
    weight_kg       numeric(5,1),
    rest_sec        smallint not null default 60 check (rest_sec between 0 and 600),
    rpe             numeric(3,1) check (rpe between 1 and 10),
    notes           text,
    unique (program_day_id, order_index)
);

-- ---------- 训练记录 ----------
create table workout_sessions (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid not null references users(id) on delete cascade,
    program_day_id uuid references program_days(id) on delete set null,
    started_at     timestamptz not null,
    finished_at    timestamptz,
    duration_min   smallint,
    feeling        smallint check (feeling between 1 and 5),
    notes          text,
    created_at     timestamptz not null default now()
);

create index workout_sessions_user_time_idx
    on workout_sessions (user_id, started_at desc);

create table set_logs (
    id            uuid primary key default gen_random_uuid(),
    session_id    uuid not null references workout_sessions(id) on delete cascade,
    exercise_slug text not null references exercises(slug),
    set_index     smallint not null,
    weight_kg     numeric(5,1),
    reps          smallint check (reps between 0 and 100),
    rpe           numeric(3,1) check (rpe between 1 and 10),
    completed     boolean not null default true,
    created_at    timestamptz not null default now()
);

create index set_logs_session_idx on set_logs (session_id);

-- ---------- 提醒 ----------
create table notification_schedules (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    weekday    smallint not null check (weekday between 1 and 7),
    hour       smallint not null check (hour between 0 and 23),
    minute     smallint not null check (minute between 0 and 59),
    enabled    boolean not null default true,
    timezone   text not null default 'Asia/Shanghai',
    created_at timestamptz not null default now(),
    unique (user_id, weekday)
);

-- ---------- AI 对话 ----------
create table chat_sessions (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    title      text not null default '新对话',
    created_at timestamptz not null default now()
);

create table chat_messages (
    id          uuid primary key default gen_random_uuid(),
    session_id  uuid not null references chat_sessions(id) on delete cascade,
    role        text not null check (role in ('user', 'assistant', 'system')),
    content     text not null,
    citations   jsonb not null default '[]',
    safety_flag text,
    tokens      integer,
    created_at  timestamptz not null default now()
);

create index chat_messages_session_idx on chat_messages (session_id, created_at);

-- ---------- 器械识别 ----------
create table equipment_scans (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    image_url  text,
    status     text not null default 'pending'
               check (status in ('pending', 'succeeded', 'failed')),
    result     jsonb not null default '[]',
    model      text,
    created_at timestamptz not null default now()
);

-- ---------- 饮食（P1） ----------
create table meal_plans (
    id              uuid primary key default gen_random_uuid(),
    user_id         uuid not null references users(id) on delete cascade,
    plan_date       date not null,
    target_kcal     integer,
    target_protein_g integer,
    target_carb_g   integer,
    target_fat_g    integer,
    plan            jsonb not null default '{}',
    created_at      timestamptz not null default now(),
    unique (user_id, plan_date)
);

create table nutrition_logs (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    log_date   date not null,
    meal_type  text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
    food_name  text not null,
    kcal       integer,
    protein_g  numeric(5,1),
    carb_g     numeric(5,1),
    fat_g      numeric(5,1),
    source     text not null default 'manual',
    created_at timestamptz not null default now()
);

create table diet_links (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    provider   text not null default 'meituan',
    deeplink   text,
    h5_url     text,
    keyword    text,
    created_at timestamptz not null default now()
);

-- ---------- AI 观测与记忆 ----------
create table ai_jobs (
    id             uuid primary key default gen_random_uuid(),
    user_id        uuid references users(id) on delete set null,
    kind           text not null,          -- plan / coach / vision / summary
    model          text,
    prompt_version text,
    input_tokens   integer,
    output_tokens  integer,
    latency_ms     integer,
    status         text not null default 'ok' check (status in ('ok', 'failed', 'fallback')),
    error          text,
    created_at     timestamptz not null default now()
);

create index ai_jobs_user_time_idx on ai_jobs (user_id, created_at desc);

create table ai_memories (
    id         uuid primary key default gen_random_uuid(),
    user_id    uuid not null references users(id) on delete cascade,
    kind       text not null,             -- preference / injury / summary / feedback
    content    text not null,
    embedding  vector(1024),
    created_at timestamptz not null default now()
);

create index ai_memories_user_idx on ai_memories (user_id, kind);
create index ai_memories_embedding_idx
    on ai_memories using hnsw (embedding vector_cosine_ops);

-- ---------- 后台管理审计 ----------
create table admin_audit_logs (
    id          uuid primary key default gen_random_uuid(),
    actor       text not null default 'admin',
    action      text not null,
    target_type text not null,
    target_id   text,
    detail      jsonb not null default '{}',
    created_at  timestamptz not null default now()
);

create index admin_audit_logs_time_idx on admin_audit_logs (created_at desc);
create index admin_audit_logs_action_idx on admin_audit_logs (action);

-- ---------- updated_at 触发器 ----------
create or replace function touch_updated_at()
returns trigger as $$
begin
    new.updated_at = now();
    return new;
end;
$$ language plpgsql;

create trigger users_touch before update on users
    for each row execute function touch_updated_at();
create trigger profiles_touch before update on profiles
    for each row execute function touch_updated_at();
