-- 主动教练（应用内收件箱提醒）的用户级开关。
-- 默认开启，保持现有行为；用户可以在设置里关闭，不再生成漏练/恢复提醒。
ALTER TABLE user_preferences
    ADD COLUMN proactive_enabled BOOLEAN NOT NULL DEFAULT TRUE;
