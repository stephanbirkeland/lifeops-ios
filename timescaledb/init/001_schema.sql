-- LifeOps Database Schema
-- TimescaleDB with time-series hypertables

-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ===========================================
-- Time-Series Tables (Hypertables)
-- ===========================================

-- Oura health metrics
CREATE TABLE IF NOT EXISTS health_metrics (
    time            TIMESTAMPTZ NOT NULL,
    metric_type     TEXT NOT NULL,
    value           DOUBLE PRECISION,
    metadata        JSONB DEFAULT '{}'::jsonb,
    source          TEXT DEFAULT 'oura'
);
SELECT create_hypertable('health_metrics', 'time', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_health_metrics_type_time ON health_metrics (metric_type, time DESC);

-- Daily summaries from Oura
CREATE TABLE IF NOT EXISTS daily_summaries (
    date            DATE PRIMARY KEY,
    sleep_score     INTEGER,
    readiness_score INTEGER,
    activity_score  INTEGER,
    sleep_data      JSONB DEFAULT '{}'::jsonb,
    readiness_data  JSONB DEFAULT '{}'::jsonb,
    activity_data   JSONB DEFAULT '{}'::jsonb,
    synced_at       TIMESTAMPTZ DEFAULT NOW()
);

-- Sensor readings (for future ESPHome sensors)
CREATE TABLE IF NOT EXISTS sensor_readings (
    time            TIMESTAMPTZ NOT NULL,
    sensor_id       TEXT NOT NULL,
    metric          TEXT NOT NULL,
    value           DOUBLE PRECISION,
    unit            TEXT
);
SELECT create_hypertable('sensor_readings', 'time', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_sensor_time ON sensor_readings (sensor_id, time DESC);

-- Habit tracking logs
CREATE TABLE IF NOT EXISTS habit_logs (
    time            TIMESTAMPTZ NOT NULL,
    habit_id        TEXT NOT NULL,
    completed       BOOLEAN DEFAULT FALSE,
    value           DOUBLE PRECISION,
    notes           TEXT
);
SELECT create_hypertable('habit_logs', 'time', if_not_exists => TRUE);
CREATE INDEX IF NOT EXISTS idx_habit_logs_habit_time ON habit_logs (habit_id, time DESC);

-- Gamification events (XP earned, achievements)
CREATE TABLE IF NOT EXISTS gamification_events (
    time            TIMESTAMPTZ NOT NULL,
    event_type      TEXT NOT NULL,
    xp_earned       INTEGER DEFAULT 0,
    details         JSONB DEFAULT '{}'::jsonb
);
SELECT create_hypertable('gamification_events', 'time', if_not_exists => TRUE);

-- ===========================================
-- Regular Tables (Configuration/State)
-- ===========================================

-- User profile and settings
CREATE TABLE IF NOT EXISTS user_profile (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name            TEXT,
    settings        JSONB DEFAULT '{}'::jsonb,

    -- Gamification state
    total_xp        INTEGER DEFAULT 0,
    level           INTEGER DEFAULT 1,

    -- Goals
    target_wake_time    TIME DEFAULT '06:00',
    target_bedtime      TIME DEFAULT '22:30',
    target_screen_hours DOUBLE PRECISION DEFAULT 3.0,
    target_gym_sessions INTEGER DEFAULT 3,

    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Streak tracking
CREATE TABLE IF NOT EXISTS streaks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    streak_type     TEXT NOT NULL UNIQUE,
    current_count   INTEGER DEFAULT 0,
    best_count      INTEGER DEFAULT 0,
    last_date       DATE,
    freeze_tokens   INTEGER DEFAULT 0,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Achievements
CREATE TABLE IF NOT EXISTS achievements (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    description     TEXT,
    tier            TEXT DEFAULT 'bronze', -- bronze, silver, gold, platinum, diamond
    xp_reward       INTEGER DEFAULT 0,
    progress        INTEGER DEFAULT 0,
    target          INTEGER DEFAULT 1,
    unlocked_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Daily scores (calculated aggregate)
CREATE TABLE IF NOT EXISTS daily_scores (
    date            DATE PRIMARY KEY,
    life_score      DOUBLE PRECISION,
    sleep_score     DOUBLE PRECISION,
    activity_score  DOUBLE PRECISION,
    worklife_score  DOUBLE PRECISION,
    habits_score    DOUBLE PRECISION,
    xp_earned       INTEGER DEFAULT 0,
    calculated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================================
-- Default Data
-- ===========================================

-- Insert default user profile
INSERT INTO user_profile (name, settings)
VALUES ('User', '{"theme": "dark", "notifications": true}'::jsonb)
ON CONFLICT DO NOTHING;

-- Insert default streaks
INSERT INTO streaks (streak_type) VALUES
    ('morning_victory'),
    ('gym_chain'),
    ('work_boundary'),
    ('screen_mastery'),
    ('sleep_consistency')
ON CONFLICT (streak_type) DO NOTHING;

-- Insert achievements
INSERT INTO achievements (code, name, description, tier, xp_reward, target) VALUES
    -- Bronze (entry level)
    ('first_70_life_score', 'Getting Started', 'Achieve your first 70+ Life Score', 'bronze', 200, 1),
    ('first_gym_session', 'Gym Initiate', 'Complete your first gym session', 'bronze', 200, 1),
    ('first_early_wake', 'Early Bird', 'Wake up before 6:00 AM', 'bronze', 200, 1),

    -- Silver (consistency)
    ('wake_streak_7', 'Week Warrior', 'Maintain 7-day early wake streak', 'silver', 500, 7),
    ('gym_4_weeks', 'Gym Regular', 'Hit gym target for 4 consecutive weeks', 'silver', 500, 4),
    ('life_score_80_week', 'High Performer', 'Average 80+ Life Score for a week', 'silver', 500, 7),

    -- Gold (mastery)
    ('wake_streak_30', 'Morning Master', 'Maintain 30-day early wake streak', 'gold', 1500, 30),
    ('life_score_80_month', 'Life Optimizer', 'Average 80+ Life Score for a month', 'gold', 1500, 30),
    ('all_domains_80', 'Balanced Life', 'Score 80+ in all domains on same day', 'gold', 1500, 1),

    -- Platinum (exceptional)
    ('wake_streak_100', 'Dawn Legend', 'Maintain 100-day early wake streak', 'platinum', 5000, 100),
    ('gym_26_weeks', 'Iron Will', 'Hit gym target for 26 consecutive weeks', 'platinum', 5000, 26),

    -- Diamond (legendary)
    ('life_score_80_year', 'Life Master', 'Average 80+ Life Score for a year', 'diamond', 15000, 365),
    ('all_gold', 'Completionist', 'Unlock all Gold achievements', 'diamond', 15000, 1)
ON CONFLICT (code) DO NOTHING;

-- ===========================================
-- Compression Policies (for older data)
-- ===========================================

SELECT add_compression_policy('health_metrics', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_compression_policy('sensor_readings', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_compression_policy('habit_logs', INTERVAL '30 days', if_not_exists => TRUE);
SELECT add_compression_policy('gamification_events', INTERVAL '30 days', if_not_exists => TRUE);

-- ===========================================
-- Continuous Aggregates (hourly/daily rollups)
-- ===========================================

-- Hourly sensor averages
CREATE MATERIALIZED VIEW IF NOT EXISTS sensor_hourly
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    sensor_id,
    metric,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*) AS sample_count
FROM sensor_readings
GROUP BY bucket, sensor_id, metric
WITH NO DATA;

-- Refresh policy for continuous aggregate
SELECT add_continuous_aggregate_policy('sensor_hourly',
    start_offset => INTERVAL '3 hours',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour',
    if_not_exists => TRUE
);
