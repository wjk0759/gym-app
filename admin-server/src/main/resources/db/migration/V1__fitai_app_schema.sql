-- FitAI application schema (MySQL 8.0+)
-- Source of truth: backend/app/models.py. Generated during the admin migration.
-- This database is shared by the FastAPI app API and the Spring Boot admin control plane.
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE admin_audit_logs (
	id VARCHAR(36) NOT NULL, 
	actor VARCHAR(80) NOT NULL, 
	action VARCHAR(80) NOT NULL, 
	target_type VARCHAR(40) NOT NULL, 
	target_id VARCHAR(80), 
	detail JSON NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE exercises (
	slug VARCHAR(60) NOT NULL, 
	name_zh VARCHAR(80) NOT NULL, 
	name_en VARCHAR(120), 
	muscle_group VARCHAR(20) NOT NULL, 
	equipment VARCHAR(20) NOT NULL, 
	is_compound BOOL NOT NULL, 
	difficulty INTEGER NOT NULL, 
	instructions TEXT, 
	video_url TEXT, 
	thumbnail_url TEXT, 
	contraindications JSON NOT NULL, 
	source VARCHAR(40), 
	license VARCHAR(120), 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE sms_codes (
	id VARCHAR(36) NOT NULL, 
	phone VARCHAR(32) NOT NULL, 
	purpose VARCHAR(20) NOT NULL, 
	code_hash VARCHAR(128) NOT NULL, 
	attempts INTEGER NOT NULL, 
	used_at DATETIME, 
	expires_at DATETIME NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE users (
	id VARCHAR(36) NOT NULL, 
	apple_sub VARCHAR(255), 
	phone VARCHAR(32), 
	username VARCHAR(50), 
	password_hash VARCHAR(255), 
	wechat_openid VARCHAR(128), 
	wechat_unionid VARCHAR(128), 
	qq_openid VARCHAR(128), 
	avatar_url TEXT, 
	status VARCHAR(20) NOT NULL, 
	last_login_at DATETIME, 
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	deleted_at DATETIME, 
	PRIMARY KEY (id), 
	UNIQUE (apple_sub), 
	UNIQUE (phone), 
	UNIQUE (wechat_openid), 
	UNIQUE (qq_openid)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ai_jobs (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36), 
	kind VARCHAR(30) NOT NULL, 
	model VARCHAR(80), 
	prompt_version VARCHAR(30), 
	input_tokens INTEGER, 
	output_tokens INTEGER, 
	latency_ms INTEGER, 
	status VARCHAR(20) NOT NULL, 
	error TEXT, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE ai_memories (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	kind VARCHAR(30) NOT NULL, 
	content TEXT NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE auth_events (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36), 
	event VARCHAR(40) NOT NULL, 
	method VARCHAR(30) NOT NULL, 
	success BOOL NOT NULL, 
	ip_address VARCHAR(64), 
	user_agent VARCHAR(255), 
	detail JSON NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE auth_sessions (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	refresh_token_hash VARCHAR(128) NOT NULL, 
	device_name VARCHAR(120), 
	ip_address VARCHAR(64), 
	user_agent VARCHAR(255), 
	created_at DATETIME NOT NULL, 
	last_used_at DATETIME NOT NULL, 
	expires_at DATETIME NOT NULL, 
	revoked_at DATETIME, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE chat_sessions (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	title VARCHAR(120) NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE equipment_scans (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	image_url TEXT, 
	status VARCHAR(20) NOT NULL, 
	result JSON NOT NULL, 
	model VARCHAR(80), 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE exercise_videos (
	id VARCHAR(36) NOT NULL, 
	exercise_slug VARCHAR(60) NOT NULL, 
	title VARCHAR(120) NOT NULL, 
	description TEXT, 
	video_url TEXT NOT NULL, 
	poster_url TEXT, 
	duration_seconds INTEGER, 
	source VARCHAR(80), 
	license_note VARCHAR(200), 
	license_expires_at DATE, 
	status VARCHAR(20) NOT NULL, 
	version INTEGER NOT NULL, 
	created_by VARCHAR(40), 
	created_at DATETIME NOT NULL, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(exercise_slug) REFERENCES exercises (slug) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE goals (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	type VARCHAR(20) NOT NULL, 
	target_weight_kg FLOAT, 
	target_body_fat_pct FLOAT, 
	target_waist_cm FLOAT, 
	target_date DATE, 
	status VARCHAR(20) NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE meal_plans (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	plan_date DATE NOT NULL, 
	target_kcal INTEGER, 
	target_protein_g INTEGER, 
	target_carb_g INTEGER, 
	target_fat_g INTEGER, 
	plan JSON NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE notification_schedules (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	weekday INTEGER NOT NULL, 
	hour INTEGER NOT NULL, 
	minute INTEGER NOT NULL, 
	enabled BOOL NOT NULL, 
	timezone VARCHAR(50) NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE oauth_tickets (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	provider VARCHAR(20) NOT NULL, 
	is_new_user BOOL NOT NULL, 
	used_at DATETIME, 
	expires_at DATETIME NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE profiles (
	user_id VARCHAR(36) NOT NULL, 
	nickname VARCHAR(50) NOT NULL, 
	sex VARCHAR(10) NOT NULL, 
	birth_date DATE, 
	height_cm FLOAT, 
	weight_kg FLOAT, 
	body_fat_pct FLOAT, 
	chest_cm FLOAT, 
	waist_cm FLOAT, 
	hip_cm FLOAT, 
	experience VARCHAR(20) NOT NULL, 
	injuries JSON NOT NULL, 
	equipment JSON NOT NULL, 
	weekly_days INTEGER NOT NULL, 
	session_minutes INTEGER NOT NULL, 
	onboarded_at DATETIME, 
	updated_at DATETIME NOT NULL, 
	PRIMARY KEY (user_id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE programs (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	title VARCHAR(120) NOT NULL, 
	goal_type VARCHAR(20) NOT NULL, 
	version INTEGER NOT NULL, 
	status VARCHAR(20) NOT NULL, 
	start_date DATE NOT NULL, 
	weeks INTEGER NOT NULL, 
	generated_by VARCHAR(20) NOT NULL, 
	model_name VARCHAR(80), 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE chat_messages (
	id VARCHAR(36) NOT NULL, 
	session_id VARCHAR(36) NOT NULL, 
	`role` VARCHAR(20) NOT NULL, 
	content TEXT NOT NULL, 
	citations JSON NOT NULL, 
	safety_flag VARCHAR(40), 
	tokens INTEGER, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(session_id) REFERENCES chat_sessions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE program_days (
	id VARCHAR(36) NOT NULL, 
	program_id VARCHAR(36) NOT NULL, 
	week_index INTEGER NOT NULL, 
	weekday INTEGER NOT NULL, 
	title VARCHAR(80) NOT NULL, 
	focus JSON NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(program_id) REFERENCES programs (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE plan_exercises (
	id VARCHAR(36) NOT NULL, 
	program_day_id VARCHAR(36) NOT NULL, 
	exercise_slug VARCHAR(60) NOT NULL, 
	order_index INTEGER NOT NULL, 
	sets INTEGER NOT NULL, 
	reps VARCHAR(20) NOT NULL, 
	weight_kg FLOAT, 
	rest_sec INTEGER NOT NULL, 
	rpe FLOAT, 
	notes TEXT, 
	PRIMARY KEY (id), 
	FOREIGN KEY(program_day_id) REFERENCES program_days (id) ON DELETE CASCADE, 
	FOREIGN KEY(exercise_slug) REFERENCES exercises (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE workout_sessions (
	id VARCHAR(36) NOT NULL, 
	user_id VARCHAR(36) NOT NULL, 
	program_day_id VARCHAR(36), 
	started_at DATETIME NOT NULL, 
	finished_at DATETIME, 
	duration_min INTEGER, 
	feeling INTEGER, 
	notes TEXT, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(user_id) REFERENCES users (id) ON DELETE CASCADE, 
	FOREIGN KEY(program_day_id) REFERENCES program_days (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE set_logs (
	id VARCHAR(36) NOT NULL, 
	session_id VARCHAR(36) NOT NULL, 
	exercise_slug VARCHAR(60) NOT NULL, 
	set_index INTEGER NOT NULL, 
	weight_kg FLOAT, 
	reps INTEGER, 
	rpe FLOAT, 
	completed BOOL NOT NULL, 
	created_at DATETIME NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE, 
	FOREIGN KEY(exercise_slug) REFERENCES exercises (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE INDEX ix_admin_audit_logs_action ON admin_audit_logs (action);

CREATE INDEX ix_exercises_equipment ON exercises (equipment);
CREATE INDEX ix_exercises_muscle_group ON exercises (muscle_group);

CREATE INDEX ix_sms_codes_phone ON sms_codes (phone);

CREATE UNIQUE INDEX ix_users_username ON users (username);
CREATE UNIQUE INDEX ix_users_wechat_unionid ON users (wechat_unionid);

CREATE INDEX ix_ai_jobs_created_at ON ai_jobs (created_at);
CREATE INDEX ix_ai_jobs_user_id ON ai_jobs (user_id);

CREATE INDEX ix_ai_memories_user_id ON ai_memories (user_id);

CREATE INDEX ix_auth_events_event ON auth_events (event);
CREATE INDEX ix_auth_events_user_id ON auth_events (user_id);

CREATE UNIQUE INDEX ix_auth_sessions_refresh_token_hash ON auth_sessions (refresh_token_hash);
CREATE INDEX ix_auth_sessions_user_id ON auth_sessions (user_id);

CREATE INDEX ix_chat_sessions_created_at ON chat_sessions (created_at);
CREATE INDEX ix_chat_sessions_user_created ON chat_sessions (user_id, created_at);
CREATE INDEX ix_chat_sessions_user_id ON chat_sessions (user_id);

CREATE INDEX ix_equipment_scans_user_id ON equipment_scans (user_id);

CREATE INDEX ix_exercise_videos_exercise_slug ON exercise_videos (exercise_slug);
CREATE INDEX ix_exercise_videos_slug_status ON exercise_videos (exercise_slug, status);
CREATE INDEX ix_exercise_videos_status ON exercise_videos (status);

CREATE INDEX ix_goals_user_id ON goals (user_id);

CREATE INDEX ix_meal_plans_user_id ON meal_plans (user_id);

CREATE INDEX ix_notification_schedules_user_id ON notification_schedules (user_id);

CREATE INDEX ix_oauth_tickets_user_id ON oauth_tickets (user_id);


CREATE INDEX ix_programs_created_at ON programs (created_at);
CREATE INDEX ix_programs_status ON programs (status);
CREATE INDEX ix_programs_user_id ON programs (user_id);
CREATE INDEX ix_programs_user_status_version ON programs (user_id, status, version);

CREATE INDEX ix_chat_messages_session_id ON chat_messages (session_id);

CREATE INDEX ix_program_days_program_id ON program_days (program_id);

CREATE INDEX ix_plan_exercises_exercise_slug ON plan_exercises (exercise_slug);
CREATE INDEX ix_plan_exercises_program_day_id ON plan_exercises (program_day_id);

CREATE INDEX ix_workout_sessions_started_at ON workout_sessions (started_at);
CREATE INDEX ix_workout_sessions_user_id ON workout_sessions (user_id);
CREATE INDEX ix_workout_sessions_user_started ON workout_sessions (user_id, started_at);

CREATE INDEX ix_set_logs_session_id ON set_logs (session_id);

SET FOREIGN_KEY_CHECKS = 1;
