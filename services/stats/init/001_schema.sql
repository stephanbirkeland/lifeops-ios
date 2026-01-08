-- Stats Service Database Schema
-- RPG-style character progression system

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===========================================
-- Characters
-- ===========================================

CREATE TABLE characters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE NOT NULL,
    name VARCHAR(100) DEFAULT 'Adventurer',

    -- Character progression
    level INTEGER DEFAULT 1,
    total_xp BIGINT DEFAULT 0,

    -- Allocatable resources
    stat_points INTEGER DEFAULT 0,
    respec_tokens INTEGER DEFAULT 1,

    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_characters_user_id ON characters(user_id);

-- ===========================================
-- Character Stats (6 core attributes)
-- ===========================================

CREATE TABLE character_stats (
    character_id UUID REFERENCES characters(id) ON DELETE CASCADE,
    stat_code VARCHAR(3) NOT NULL, -- STR, INT, WIS, STA, CHA, LCK

    -- Base value from passive XP growth
    base_value INTEGER DEFAULT 10,
    stat_xp BIGINT DEFAULT 0,

    -- Bonus from tree allocations
    allocated_bonus INTEGER DEFAULT 0,

    PRIMARY KEY (character_id, stat_code)
);

CREATE INDEX idx_character_stats_character ON character_stats(character_id);

-- ===========================================
-- Stat Tree Nodes
-- ===========================================

CREATE TABLE stat_nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Classification
    node_type VARCHAR(20) NOT NULL DEFAULT 'minor', -- origin, minor, notable, keystone, skill
    tree_branch VARCHAR(10), -- STR, INT, WIS, STA, CHA, LCK, HYBRID, ORIGIN

    -- Visual position for tree rendering
    position_x FLOAT DEFAULT 0,
    position_y FLOAT DEFAULT 0,

    -- Requirements
    required_points INTEGER DEFAULT 1,
    prerequisite_nodes UUID[] DEFAULT '{}',

    -- Effects (JSONB for flexibility)
    effects JSONB DEFAULT '[]',

    -- Metadata
    icon VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_stat_nodes_code ON stat_nodes(code);
CREATE INDEX idx_stat_nodes_branch ON stat_nodes(tree_branch);
CREATE INDEX idx_stat_nodes_type ON stat_nodes(node_type);

-- ===========================================
-- Stat Node Edges (Graph connections)
-- ===========================================

CREATE TABLE stat_node_edges (
    from_node_id UUID REFERENCES stat_nodes(id) ON DELETE CASCADE,
    to_node_id UUID REFERENCES stat_nodes(id) ON DELETE CASCADE,
    bidirectional BOOLEAN DEFAULT true,

    PRIMARY KEY (from_node_id, to_node_id)
);

CREATE INDEX idx_stat_node_edges_from ON stat_node_edges(from_node_id);
CREATE INDEX idx_stat_node_edges_to ON stat_node_edges(to_node_id);

-- ===========================================
-- Character Node Allocations
-- ===========================================

CREATE TABLE character_nodes (
    character_id UUID REFERENCES characters(id) ON DELETE CASCADE,
    node_id UUID REFERENCES stat_nodes(id) ON DELETE CASCADE,
    allocated_at TIMESTAMPTZ DEFAULT NOW(),

    PRIMARY KEY (character_id, node_id)
);

CREATE INDEX idx_character_nodes_character ON character_nodes(character_id);

-- ===========================================
-- Activity Log (XP source tracking)
-- ===========================================

CREATE TABLE activity_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    character_id UUID REFERENCES characters(id) ON DELETE CASCADE,

    -- Activity details
    activity_type VARCHAR(100) NOT NULL,
    activity_data JSONB DEFAULT '{}',
    source VARCHAR(50) NOT NULL, -- lifeops, challengemode, manual
    source_ref VARCHAR(255), -- External reference ID

    -- XP granted
    xp_grants JSONB DEFAULT '{}', -- {"STR": 50, "STA": 20}

    -- Timestamps
    activity_time TIMESTAMPTZ NOT NULL,
    logged_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_activity_log_character ON activity_log(character_id);
CREATE INDEX idx_activity_log_type ON activity_log(activity_type);
CREATE INDEX idx_activity_log_source ON activity_log(source);
CREATE INDEX idx_activity_log_time ON activity_log(activity_time DESC);

-- ===========================================
-- Derived Stats (Calculated from core stats)
-- ===========================================

CREATE TABLE derived_stats (
    code VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Formula for calculation
    formula VARCHAR(500) NOT NULL, -- e.g., "STR * 1.5 + INT * 0.5"

    -- Source stats (for UI hints)
    source_stats VARCHAR(3)[] DEFAULT '{}',

    is_active BOOLEAN DEFAULT true
);

-- ===========================================
-- Skills (Unlockable abilities)
-- ===========================================

CREATE TABLE skills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Unlock requirements
    required_node_id UUID REFERENCES stat_nodes(id),
    stat_requirements JSONB DEFAULT '{}', -- {"STR": 20, "STA": 15}

    -- Skill properties
    effects JSONB DEFAULT '{}',
    cooldown INTERVAL,

    is_active BOOLEAN DEFAULT true
);

CREATE INDEX idx_skills_code ON skills(code);

-- ===========================================
-- Character Skills (Unlocked skills)
-- ===========================================

CREATE TABLE character_skills (
    character_id UUID REFERENCES characters(id) ON DELETE CASCADE,
    skill_id UUID REFERENCES skills(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ DEFAULT NOW(),
    times_used INTEGER DEFAULT 0,
    last_used TIMESTAMPTZ,

    PRIMARY KEY (character_id, skill_id)
);

CREATE INDEX idx_character_skills_character ON character_skills(character_id);

-- ===========================================
-- Level XP Requirements
-- ===========================================

CREATE TABLE level_thresholds (
    level INTEGER PRIMARY KEY,
    xp_required BIGINT NOT NULL,
    stat_points_granted INTEGER DEFAULT 1
);

-- Populate level thresholds (1-100)
INSERT INTO level_thresholds (level, xp_required, stat_points_granted)
SELECT
    level,
    CASE
        WHEN level = 1 THEN 0
        ELSE FLOOR(100 * POWER(level - 1, 1.8))::BIGINT
    END as xp_required,
    CASE
        WHEN level % 10 = 0 THEN 3  -- Major levels
        WHEN level % 5 = 0 THEN 2   -- Notable levels
        ELSE 1                       -- Regular levels
    END as stat_points_granted
FROM generate_series(1, 100) as level;

-- ===========================================
-- Stat XP Thresholds (for base stat growth)
-- ===========================================

CREATE TABLE stat_level_thresholds (
    level INTEGER PRIMARY KEY,
    xp_required BIGINT NOT NULL
);

-- Populate stat level thresholds (base value 10-100)
INSERT INTO stat_level_thresholds (level, xp_required)
SELECT
    level,
    CASE
        WHEN level <= 10 THEN 0
        ELSE FLOOR(50 * POWER(level - 10, 1.5))::BIGINT
    END as xp_required
FROM generate_series(10, 100) as level;

-- ===========================================
-- Functions
-- ===========================================

-- Function to update character timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER characters_updated_at
    BEFORE UPDATE ON characters
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- Function to calculate level from XP
CREATE OR REPLACE FUNCTION get_level_from_xp(xp BIGINT)
RETURNS INTEGER AS $$
BEGIN
    RETURN COALESCE(
        (SELECT MAX(level) FROM level_thresholds WHERE xp_required <= xp),
        1
    );
END;
$$ LANGUAGE plpgsql;

-- Function to calculate stat base value from XP
CREATE OR REPLACE FUNCTION get_stat_level_from_xp(xp BIGINT)
RETURNS INTEGER AS $$
BEGIN
    RETURN COALESCE(
        (SELECT MAX(level) FROM stat_level_thresholds WHERE xp_required <= xp),
        10
    );
END;
$$ LANGUAGE plpgsql;

-- Function to get XP required for next level
CREATE OR REPLACE FUNCTION get_xp_for_next_level(current_level INTEGER)
RETURNS BIGINT AS $$
BEGIN
    RETURN COALESCE(
        (SELECT xp_required FROM level_thresholds WHERE level = current_level + 1),
        (SELECT MAX(xp_required) FROM level_thresholds)
    );
END;
$$ LANGUAGE plpgsql;

-- ===========================================
-- Initial Derived Stats
-- ===========================================

INSERT INTO derived_stats (code, name, description, formula, source_stats) VALUES
('POWER', 'Power', 'Raw physical and mental might', 'STR * 0.6 + INT * 0.4', ARRAY['STR', 'INT']),
('RESILIENCE', 'Resilience', 'Ability to recover and endure', 'STA * 0.7 + WIS * 0.3', ARRAY['STA', 'WIS']),
('INFLUENCE', 'Influence', 'Social impact and persuasion', 'CHA * 0.6 + INT * 0.3 + LCK * 0.1', ARRAY['CHA', 'INT', 'LCK']),
('FORTUNE', 'Fortune', 'Chance of favorable outcomes', 'LCK * 0.8 + WIS * 0.2', ARRAY['LCK', 'WIS']),
('FOCUS', 'Focus', 'Mental clarity and concentration', 'INT * 0.5 + WIS * 0.5', ARRAY['INT', 'WIS']),
('VITALITY', 'Vitality', 'Overall health and energy', 'STA * 0.5 + STR * 0.3 + WIS * 0.2', ARRAY['STA', 'STR', 'WIS']);

-- ===========================================
-- Comments
-- ===========================================

COMMENT ON TABLE characters IS 'User character profiles with progression tracking';
COMMENT ON TABLE character_stats IS 'Core attribute values (STR, INT, WIS, STA, CHA, LCK) per character';
COMMENT ON TABLE stat_nodes IS 'Skill tree node definitions with effects';
COMMENT ON TABLE stat_node_edges IS 'Graph connections between tree nodes';
COMMENT ON TABLE character_nodes IS 'Nodes allocated by each character';
COMMENT ON TABLE activity_log IS 'Activity events that grant XP';
COMMENT ON TABLE derived_stats IS 'Calculated stats from formulas';
COMMENT ON TABLE skills IS 'Unlockable abilities';
COMMENT ON TABLE character_skills IS 'Skills unlocked by each character';
