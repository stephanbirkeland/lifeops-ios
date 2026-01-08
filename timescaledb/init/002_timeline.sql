-- Timeline Feature Schema
-- Rolling task/event timeline with smart scheduling

-- ===========================================
-- Time Anchors (User's reference points)
-- ===========================================

CREATE TABLE IF NOT EXISTS time_anchors (
    code            TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    default_time    TIME NOT NULL,
    description     TEXT
);

-- Default time anchors
INSERT INTO time_anchors (code, name, default_time, description) VALUES
    ('morning', 'Morning', '07:00', 'Start of morning routine'),
    ('mid_morning', 'Mid-Morning', '10:00', 'Mid-morning break'),
    ('lunch', 'Lunch', '12:00', 'Lunch break'),
    ('afternoon', 'Afternoon', '14:00', 'Early afternoon'),
    ('after_work', 'After Work', '17:00', 'End of work day'),
    ('evening', 'Evening', '19:00', 'Evening time'),
    ('night', 'Night', '21:00', 'Night routine'),
    ('bedtime', 'Bedtime', '22:30', 'Preparing for bed')
ON CONFLICT (code) DO NOTHING;

-- ===========================================
-- Timeline Items (Definitions)
-- ===========================================

CREATE TABLE IF NOT EXISTS timeline_items (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    description     TEXT,
    icon            TEXT,

    -- Scheduling
    schedule_type   TEXT NOT NULL DEFAULT 'daily',  -- daily, weekdays, weekends, weekly, specific_days, once
    schedule_days   INTEGER[] DEFAULT '{}',         -- 0=Mon, 6=Sun (for weekly/specific_days)
    anchor          TEXT REFERENCES time_anchors(code),  -- time anchor reference
    time_offset     INTEGER DEFAULT 0,              -- minutes offset from anchor
    exact_time      TIME,                           -- OR exact time (overrides anchor)

    -- Time window
    window_minutes  INTEGER DEFAULT 60,             -- how long item stays active

    -- For one-time items
    scheduled_date  DATE,                           -- specific date for 'once' type

    -- Integration
    stat_rewards    JSONB DEFAULT '{}',             -- {"STR": 20, "STA": 10}

    -- Priority and display
    priority        INTEGER DEFAULT 5,              -- 1=highest, 10=lowest
    category        TEXT DEFAULT 'task',            -- task, chore, habit, reminder

    -- State
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_timeline_items_active ON timeline_items (is_active);
CREATE INDEX IF NOT EXISTS idx_timeline_items_anchor ON timeline_items (anchor);

-- ===========================================
-- Timeline Overrides (Postponements/Reschedules)
-- ===========================================

CREATE TABLE IF NOT EXISTS timeline_overrides (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID REFERENCES timeline_items(id) ON DELETE CASCADE,
    original_date   DATE NOT NULL,

    -- Override type
    override_type   TEXT NOT NULL,  -- postpone, skip, reschedule

    -- New schedule (for postpone/reschedule)
    new_date        DATE,
    new_time        TIME,
    new_anchor      TEXT REFERENCES time_anchors(code),

    -- Metadata
    reason          TEXT,
    created_at      TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(item_id, original_date)
);

CREATE INDEX IF NOT EXISTS idx_timeline_overrides_date ON timeline_overrides (original_date);
CREATE INDEX IF NOT EXISTS idx_timeline_overrides_new_date ON timeline_overrides (new_date);

-- ===========================================
-- Timeline Completions
-- ===========================================

CREATE TABLE IF NOT EXISTS timeline_completions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    item_id         UUID REFERENCES timeline_items(id) ON DELETE CASCADE,
    completed_date  DATE NOT NULL,
    completed_at    TIMESTAMPTZ DEFAULT NOW(),

    -- Optional data
    notes           TEXT,
    duration_minutes INTEGER,

    -- Stats integration (XP sent to Stats Service)
    xp_granted      JSONB DEFAULT '{}',

    UNIQUE(item_id, completed_date)
);

CREATE INDEX IF NOT EXISTS idx_timeline_completions_date ON timeline_completions (completed_date);

-- ===========================================
-- Calendar Events (External calendars)
-- ===========================================

CREATE TABLE IF NOT EXISTS calendar_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    external_id     TEXT,                           -- ID from external calendar
    source          TEXT NOT NULL,                  -- google, apple, manual

    -- Event details
    title           TEXT NOT NULL,
    description     TEXT,
    location        TEXT,

    -- Timing
    start_time      TIMESTAMPTZ NOT NULL,
    end_time        TIMESTAMPTZ,
    all_day         BOOLEAN DEFAULT FALSE,

    -- Event classification
    event_type      TEXT DEFAULT 'event',           -- event, meeting, appointment, reminder

    -- Generated tasks
    prep_minutes    INTEGER DEFAULT 0,              -- create "prep" task N minutes before
    travel_minutes  INTEGER DEFAULT 0,              -- buffer for travel

    -- Sync metadata
    synced_at       TIMESTAMPTZ DEFAULT NOW(),
    raw_data        JSONB DEFAULT '{}',

    UNIQUE(source, external_id)
);

CREATE INDEX IF NOT EXISTS idx_calendar_events_time ON calendar_events (start_time);
CREATE INDEX IF NOT EXISTS idx_calendar_events_source ON calendar_events (source);

-- ===========================================
-- Streak Tracking for Timeline Items
-- ===========================================

CREATE TABLE IF NOT EXISTS timeline_streaks (
    item_id         UUID PRIMARY KEY REFERENCES timeline_items(id) ON DELETE CASCADE,
    current_streak  INTEGER DEFAULT 0,
    best_streak     INTEGER DEFAULT 0,
    last_completed  DATE,
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- ===========================================
-- Functions
-- ===========================================

-- Get effective time for an item (considering anchor + offset or exact time)
CREATE OR REPLACE FUNCTION get_item_time(item timeline_items, for_date DATE)
RETURNS TIME AS $$
DECLARE
    anchor_time TIME;
BEGIN
    -- If exact time is set, use it
    IF item.exact_time IS NOT NULL THEN
        RETURN item.exact_time;
    END IF;

    -- Otherwise, get anchor time and apply offset
    IF item.anchor IS NOT NULL THEN
        SELECT default_time INTO anchor_time FROM time_anchors WHERE code = item.anchor;
        RETURN anchor_time + (item.time_offset * INTERVAL '1 minute');
    END IF;

    -- Default to morning
    RETURN '07:00'::TIME;
END;
$$ LANGUAGE plpgsql;

-- Check if item should appear on a given date
CREATE OR REPLACE FUNCTION item_applies_to_date(item timeline_items, check_date DATE)
RETURNS BOOLEAN AS $$
DECLARE
    day_of_week INTEGER;
BEGIN
    day_of_week := EXTRACT(DOW FROM check_date)::INTEGER;
    -- Convert Sunday=0 to Monday=0 format
    day_of_week := CASE WHEN day_of_week = 0 THEN 6 ELSE day_of_week - 1 END;

    CASE item.schedule_type
        WHEN 'daily' THEN
            RETURN TRUE;
        WHEN 'weekdays' THEN
            RETURN day_of_week BETWEEN 0 AND 4;
        WHEN 'weekends' THEN
            RETURN day_of_week IN (5, 6);
        WHEN 'weekly', 'specific_days' THEN
            RETURN day_of_week = ANY(item.schedule_days);
        WHEN 'once' THEN
            RETURN item.scheduled_date = check_date;
        ELSE
            RETURN TRUE;
    END CASE;
END;
$$ LANGUAGE plpgsql;

-- Update streak on completion
CREATE OR REPLACE FUNCTION update_timeline_streak()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO timeline_streaks (item_id, current_streak, best_streak, last_completed, updated_at)
    VALUES (NEW.item_id, 1, 1, NEW.completed_date, NOW())
    ON CONFLICT (item_id) DO UPDATE SET
        current_streak = CASE
            WHEN timeline_streaks.last_completed = NEW.completed_date - 1
            THEN timeline_streaks.current_streak + 1
            WHEN timeline_streaks.last_completed = NEW.completed_date
            THEN timeline_streaks.current_streak
            ELSE 1
        END,
        best_streak = GREATEST(
            timeline_streaks.best_streak,
            CASE
                WHEN timeline_streaks.last_completed = NEW.completed_date - 1
                THEN timeline_streaks.current_streak + 1
                ELSE 1
            END
        ),
        last_completed = NEW.completed_date,
        updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_timeline_streak
    AFTER INSERT ON timeline_completions
    FOR EACH ROW
    EXECUTE FUNCTION update_timeline_streak();

-- ===========================================
-- Sample Timeline Items
-- ===========================================

INSERT INTO timeline_items (code, name, description, schedule_type, anchor, time_offset, window_minutes, stat_rewards, category) VALUES
    -- Morning routine
    ('morning_stretch', 'Morning Stretch', '5-10 minutes of stretching', 'daily', 'morning', 0, 60, '{"STR": 15, "STA": 10}', 'habit'),
    ('make_bed', 'Make Bed', 'Make your bed', 'daily', 'morning', 15, 45, '{"WIS": 5}', 'chore'),
    ('morning_hygiene', 'Morning Hygiene', 'Brush teeth, wash face', 'daily', 'morning', 30, 30, '{"STA": 5}', 'habit'),

    -- Work day
    ('review_calendar', 'Review Calendar', 'Check today''s schedule', 'weekdays', 'morning', 60, 30, '{"INT": 10, "WIS": 5}', 'task'),

    -- Evening routine
    ('evening_tidy', 'Evening Tidy', '10 minute tidy up', 'daily', 'evening', 0, 120, '{"WIS": 10, "STA": 5}', 'chore'),
    ('evening_journal', 'Evening Journal', 'Reflect on the day', 'daily', 'night', 0, 60, '{"WIS": 20, "INT": 10}', 'habit'),
    ('prep_tomorrow', 'Prep Tomorrow', 'Lay out clothes, pack bag', 'weekdays', 'night', 30, 60, '{"WIS": 15}', 'task'),

    -- Weekly chores
    ('laundry', 'Do Laundry', 'Wash and dry clothes', 'specific_days', 'mid_morning', 0, 180, '{"STA": 10}', 'chore'),
    ('trash_out', 'Take Out Trash', 'Empty all trash bins', 'specific_days', 'evening', -30, 60, '{"STA": 5}', 'chore')
ON CONFLICT (code) DO NOTHING;

-- Set laundry to Wednesday and Sunday
UPDATE timeline_items SET schedule_days = ARRAY[2, 6] WHERE code = 'laundry';

-- Set trash to Tuesday evening
UPDATE timeline_items SET schedule_days = ARRAY[1] WHERE code = 'trash_out';
