-- Stat Tree Seed Data
-- ~50 initial nodes organized by branch

-- ===========================================
-- ORIGIN NODE (Center of tree)
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES (
    'ORIGIN',
    'Origin',
    'The starting point of your journey',
    'origin',
    'ORIGIN',
    0, 0,
    0,
    '[]'::jsonb
);

-- ===========================================
-- STRENGTH BRANCH (Top-left)
-- ===========================================

-- Minor nodes
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('STR_1', 'Raw Power I', '+2 Strength', 'minor', 'STR', -1, -1, 1,
 '[{"type": "stat_bonus", "stat": "STR", "value": 2}]'::jsonb),
('STR_2', 'Raw Power II', '+2 Strength', 'minor', 'STR', -2, -1.5, 1,
 '[{"type": "stat_bonus", "stat": "STR", "value": 2}]'::jsonb),
('STR_3', 'Raw Power III', '+3 Strength', 'minor', 'STR', -3, -2, 1,
 '[{"type": "stat_bonus", "stat": "STR", "value": 3}]'::jsonb),
('STR_4', 'Iron Will', '+2 Strength, +1 Stamina', 'minor', 'STR', -2, -2.5, 1,
 '[{"type": "stat_bonus", "stat": "STR", "value": 2}, {"type": "stat_bonus", "stat": "STA", "value": 1}]'::jsonb);

-- Notable node
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('STR_NOTABLE_1', 'Titan''s Grip', '+5 Strength, +10% Physical XP', 'notable', 'STR', -4, -2.5, 2,
 '[{"type": "stat_bonus", "stat": "STR", "value": 5}, {"type": "xp_multiplier", "domain": "physical", "value_percent": 10}]'::jsonb);

-- Keystone
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('STR_KEYSTONE', 'Unstoppable Force', '+15 Strength, -5 Intelligence. Your physical activities grant bonus XP.', 'keystone', 'STR', -5, -3, 3,
 '[{"type": "stat_bonus", "stat": "STR", "value": 15}, {"type": "stat_bonus", "stat": "INT", "value": -5}, {"type": "xp_multiplier", "domain": "physical", "value_percent": 25}]'::jsonb);

-- ===========================================
-- INTELLIGENCE BRANCH (Top-right)
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('INT_1', 'Sharp Mind I', '+2 Intelligence', 'minor', 'INT', 1, -1, 1,
 '[{"type": "stat_bonus", "stat": "INT", "value": 2}]'::jsonb),
('INT_2', 'Sharp Mind II', '+2 Intelligence', 'minor', 'INT', 2, -1.5, 1,
 '[{"type": "stat_bonus", "stat": "INT", "value": 2}]'::jsonb),
('INT_3', 'Sharp Mind III', '+3 Intelligence', 'minor', 'INT', 3, -2, 1,
 '[{"type": "stat_bonus", "stat": "INT", "value": 3}]'::jsonb),
('INT_4', 'Quick Learner', '+2 Intelligence, +1 Wisdom', 'minor', 'INT', 2, -2.5, 1,
 '[{"type": "stat_bonus", "stat": "INT", "value": 2}, {"type": "stat_bonus", "stat": "WIS", "value": 1}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('INT_NOTABLE_1', 'Scholar''s Focus', '+5 Intelligence, +10% Learning XP', 'notable', 'INT', 4, -2.5, 2,
 '[{"type": "stat_bonus", "stat": "INT", "value": 5}, {"type": "xp_multiplier", "domain": "learning", "value_percent": 10}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('INT_KEYSTONE', 'Mastermind', '+15 Intelligence, -5 Charisma. Learning activities grant massive XP.', 'keystone', 'INT', 5, -3, 3,
 '[{"type": "stat_bonus", "stat": "INT", "value": 15}, {"type": "stat_bonus", "stat": "CHA", "value": -5}, {"type": "xp_multiplier", "domain": "learning", "value_percent": 25}]'::jsonb);

-- ===========================================
-- WISDOM BRANCH (Right)
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('WIS_1', 'Inner Peace I', '+2 Wisdom', 'minor', 'WIS', 1.5, 0, 1,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 2}]'::jsonb),
('WIS_2', 'Inner Peace II', '+2 Wisdom', 'minor', 'WIS', 2.5, 0.5, 1,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 2}]'::jsonb),
('WIS_3', 'Inner Peace III', '+3 Wisdom', 'minor', 'WIS', 3.5, 0, 1,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 3}]'::jsonb),
('WIS_4', 'Mindful Balance', '+2 Wisdom, +1 Stamina', 'minor', 'WIS', 3, 1, 1,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 2}, {"type": "stat_bonus", "stat": "STA", "value": 1}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('WIS_NOTABLE_1', 'Sage''s Insight', '+5 Wisdom, +10% Meditation XP', 'notable', 'WIS', 4.5, 0.5, 2,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 5}, {"type": "xp_multiplier", "domain": "mindfulness", "value_percent": 10}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('WIS_KEYSTONE', 'Enlightened', '+15 Wisdom, -5 Luck. Mindfulness practices are amplified.', 'keystone', 'WIS', 5.5, 0, 3,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 15}, {"type": "stat_bonus", "stat": "LCK", "value": -5}, {"type": "xp_multiplier", "domain": "mindfulness", "value_percent": 25}]'::jsonb);

-- ===========================================
-- STAMINA BRANCH (Bottom-right)
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('STA_1', 'Endurance I', '+2 Stamina', 'minor', 'STA', 1, 1, 1,
 '[{"type": "stat_bonus", "stat": "STA", "value": 2}]'::jsonb),
('STA_2', 'Endurance II', '+2 Stamina', 'minor', 'STA', 2, 1.5, 1,
 '[{"type": "stat_bonus", "stat": "STA", "value": 2}]'::jsonb),
('STA_3', 'Endurance III', '+3 Stamina', 'minor', 'STA', 3, 2, 1,
 '[{"type": "stat_bonus", "stat": "STA", "value": 3}]'::jsonb),
('STA_4', 'Vital Force', '+2 Stamina, +1 Strength', 'minor', 'STA', 2, 2.5, 1,
 '[{"type": "stat_bonus", "stat": "STA", "value": 2}, {"type": "stat_bonus", "stat": "STR", "value": 1}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('STA_NOTABLE_1', 'Iron Constitution', '+5 Stamina, +10% Sleep XP', 'notable', 'STA', 4, 2.5, 2,
 '[{"type": "stat_bonus", "stat": "STA", "value": 5}, {"type": "xp_multiplier", "domain": "health", "value_percent": 10}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('STA_KEYSTONE', 'Indomitable', '+15 Stamina, -5 Wisdom. Recovery and health activities are amplified.', 'keystone', 'STA', 5, 3, 3,
 '[{"type": "stat_bonus", "stat": "STA", "value": 15}, {"type": "stat_bonus", "stat": "WIS", "value": -5}, {"type": "xp_multiplier", "domain": "health", "value_percent": 25}]'::jsonb);

-- ===========================================
-- CHARISMA BRANCH (Bottom-left)
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('CHA_1', 'Social Grace I', '+2 Charisma', 'minor', 'CHA', -1, 1, 1,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 2}]'::jsonb),
('CHA_2', 'Social Grace II', '+2 Charisma', 'minor', 'CHA', -2, 1.5, 1,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 2}]'::jsonb),
('CHA_3', 'Social Grace III', '+3 Charisma', 'minor', 'CHA', -3, 2, 1,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 3}]'::jsonb),
('CHA_4', 'Inspiring Presence', '+2 Charisma, +1 Intelligence', 'minor', 'CHA', -2, 2.5, 1,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 2}, {"type": "stat_bonus", "stat": "INT", "value": 1}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('CHA_NOTABLE_1', 'Natural Leader', '+5 Charisma, +10% Social XP', 'notable', 'CHA', -4, 2.5, 2,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 5}, {"type": "xp_multiplier", "domain": "social", "value_percent": 10}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('CHA_KEYSTONE', 'Magnetic Personality', '+15 Charisma, -5 Stamina. Social activities grant massive XP.', 'keystone', 'CHA', -5, 3, 3,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 15}, {"type": "stat_bonus", "stat": "STA", "value": -5}, {"type": "xp_multiplier", "domain": "social", "value_percent": 25}]'::jsonb);

-- ===========================================
-- LUCK BRANCH (Left)
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('LCK_1', 'Fortune''s Favor I', '+2 Luck', 'minor', 'LCK', -1.5, 0, 1,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 2}]'::jsonb),
('LCK_2', 'Fortune''s Favor II', '+2 Luck', 'minor', 'LCK', -2.5, -0.5, 1,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 2}]'::jsonb),
('LCK_3', 'Fortune''s Favor III', '+3 Luck', 'minor', 'LCK', -3.5, 0, 1,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 3}]'::jsonb),
('LCK_4', 'Serendipity', '+2 Luck, +1 Charisma', 'minor', 'LCK', -3, -1, 1,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 2}, {"type": "stat_bonus", "stat": "CHA", "value": 1}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('LCK_NOTABLE_1', 'Lucky Star', '+5 Luck, +5% All XP', 'notable', 'LCK', -4.5, -0.5, 2,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 5}, {"type": "xp_multiplier", "domain": "all", "value_percent": 5}]'::jsonb);

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('LCK_KEYSTONE', 'Destiny''s Chosen', '+15 Luck, -5 Strength. Random bonuses from all activities.', 'keystone', 'LCK', -5.5, 0, 3,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 15}, {"type": "stat_bonus", "stat": "STR", "value": -5}, {"type": "special", "code": "random_bonus", "description": "10% chance of double XP on any activity"}]'::jsonb);

-- ===========================================
-- HYBRID NODES (Connecting branches)
-- ===========================================

-- STR-INT hybrid
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('HYBRID_STR_INT', 'Strategic Mind', '+3 Strength, +3 Intelligence', 'notable', 'HYBRID', 0, -2, 2,
 '[{"type": "stat_bonus", "stat": "STR", "value": 3}, {"type": "stat_bonus", "stat": "INT", "value": 3}]'::jsonb);

-- INT-WIS hybrid
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('HYBRID_INT_WIS', 'Analytical Insight', '+3 Intelligence, +3 Wisdom', 'notable', 'HYBRID', 2.5, -1, 2,
 '[{"type": "stat_bonus", "stat": "INT", "value": 3}, {"type": "stat_bonus", "stat": "WIS", "value": 3}]'::jsonb);

-- WIS-STA hybrid
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('HYBRID_WIS_STA', 'Mindful Body', '+3 Wisdom, +3 Stamina', 'notable', 'HYBRID', 2.5, 1, 2,
 '[{"type": "stat_bonus", "stat": "WIS", "value": 3}, {"type": "stat_bonus", "stat": "STA", "value": 3}]'::jsonb);

-- STA-CHA hybrid
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('HYBRID_STA_CHA', 'Energetic Presence', '+3 Stamina, +3 Charisma', 'notable', 'HYBRID', 0, 2, 2,
 '[{"type": "stat_bonus", "stat": "STA", "value": 3}, {"type": "stat_bonus", "stat": "CHA", "value": 3}]'::jsonb);

-- CHA-LCK hybrid
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('HYBRID_CHA_LCK', 'Fortunate Charm', '+3 Charisma, +3 Luck', 'notable', 'HYBRID', -2.5, 1, 2,
 '[{"type": "stat_bonus", "stat": "CHA", "value": 3}, {"type": "stat_bonus", "stat": "LCK", "value": 3}]'::jsonb);

-- LCK-STR hybrid
INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('HYBRID_LCK_STR', 'Fortuitous Strength', '+3 Luck, +3 Strength', 'notable', 'HYBRID', -2.5, -1, 2,
 '[{"type": "stat_bonus", "stat": "LCK", "value": 3}, {"type": "stat_bonus", "stat": "STR", "value": 3}]'::jsonb);

-- ===========================================
-- SKILL NODES
-- ===========================================

INSERT INTO stat_nodes (code, name, description, node_type, tree_branch, position_x, position_y, required_points, effects)
VALUES
('SKILL_SECOND_WIND', 'Second Wind', 'Unlock the Second Wind skill: Once per day, reduce cooldown on next activity', 'skill', 'STA', 4, 3.5, 2,
 '[{"type": "unlock_skill", "skill_code": "SECOND_WIND"}]'::jsonb),
('SKILL_INSIGHT', 'Flash of Insight', 'Unlock the Insight skill: Once per day, gain bonus XP on learning activity', 'skill', 'INT', 4.5, -3.5, 2,
 '[{"type": "unlock_skill", "skill_code": "INSIGHT"}]'::jsonb),
('SKILL_INSPIRE', 'Inspiring Words', 'Unlock the Inspire skill: Once per day, motivational boost', 'skill', 'CHA', -4.5, 3.5, 2,
 '[{"type": "unlock_skill", "skill_code": "INSPIRE"}]'::jsonb);

-- ===========================================
-- EDGES (Connections between nodes)
-- ===========================================

-- Origin to first nodes of each branch
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT o.id, n.id, true
FROM stat_nodes o, stat_nodes n
WHERE o.code = 'ORIGIN'
AND n.code IN ('STR_1', 'INT_1', 'WIS_1', 'STA_1', 'CHA_1', 'LCK_1');

-- STR branch connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_1' AND b.code = 'STR_2';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_2' AND b.code = 'STR_3';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_2' AND b.code = 'STR_4';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_3' AND b.code = 'STR_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_4' AND b.code = 'STR_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_NOTABLE_1' AND b.code = 'STR_KEYSTONE';

-- INT branch connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_1' AND b.code = 'INT_2';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_2' AND b.code = 'INT_3';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_2' AND b.code = 'INT_4';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_3' AND b.code = 'INT_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_4' AND b.code = 'INT_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_NOTABLE_1' AND b.code = 'INT_KEYSTONE';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_NOTABLE_1' AND b.code = 'SKILL_INSIGHT';

-- WIS branch connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_1' AND b.code = 'WIS_2';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_2' AND b.code = 'WIS_3';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_2' AND b.code = 'WIS_4';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_3' AND b.code = 'WIS_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_4' AND b.code = 'WIS_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_NOTABLE_1' AND b.code = 'WIS_KEYSTONE';

-- STA branch connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_1' AND b.code = 'STA_2';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_2' AND b.code = 'STA_3';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_2' AND b.code = 'STA_4';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_3' AND b.code = 'STA_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_4' AND b.code = 'STA_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_NOTABLE_1' AND b.code = 'STA_KEYSTONE';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_NOTABLE_1' AND b.code = 'SKILL_SECOND_WIND';

-- CHA branch connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_1' AND b.code = 'CHA_2';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_2' AND b.code = 'CHA_3';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_2' AND b.code = 'CHA_4';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_3' AND b.code = 'CHA_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_4' AND b.code = 'CHA_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_NOTABLE_1' AND b.code = 'CHA_KEYSTONE';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_NOTABLE_1' AND b.code = 'SKILL_INSPIRE';

-- LCK branch connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_1' AND b.code = 'LCK_2';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_2' AND b.code = 'LCK_3';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_2' AND b.code = 'LCK_4';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_3' AND b.code = 'LCK_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_4' AND b.code = 'LCK_NOTABLE_1';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_NOTABLE_1' AND b.code = 'LCK_KEYSTONE';

-- Hybrid node connections
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_4' AND b.code = 'HYBRID_STR_INT';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_4' AND b.code = 'HYBRID_STR_INT';

INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'INT_3' AND b.code = 'HYBRID_INT_WIS';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_2' AND b.code = 'HYBRID_INT_WIS';

INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'WIS_4' AND b.code = 'HYBRID_WIS_STA';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_2' AND b.code = 'HYBRID_WIS_STA';

INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STA_4' AND b.code = 'HYBRID_STA_CHA';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_4' AND b.code = 'HYBRID_STA_CHA';

INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'CHA_3' AND b.code = 'HYBRID_CHA_LCK';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_2' AND b.code = 'HYBRID_CHA_LCK';

INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'LCK_4' AND b.code = 'HYBRID_LCK_STR';
INSERT INTO stat_node_edges (from_node_id, to_node_id, bidirectional)
SELECT a.id, b.id, true FROM stat_nodes a, stat_nodes b WHERE a.code = 'STR_2' AND b.code = 'HYBRID_LCK_STR';

-- ===========================================
-- INITIAL SKILLS
-- ===========================================

INSERT INTO skills (code, name, description, stat_requirements, effects, cooldown)
VALUES
('SECOND_WIND', 'Second Wind', 'Recover energy when fatigued. Grants bonus XP on next health activity.',
 '{"STA": 15}'::jsonb,
 '{"xp_bonus": 50, "domain": "health"}'::jsonb,
 INTERVAL '24 hours'),
('INSIGHT', 'Flash of Insight', 'A moment of clarity. Grants bonus XP on next learning activity.',
 '{"INT": 15}'::jsonb,
 '{"xp_bonus": 50, "domain": "learning"}'::jsonb,
 INTERVAL '24 hours'),
('INSPIRE', 'Inspiring Words', 'Motivate yourself or others. Grants bonus XP on next social activity.',
 '{"CHA": 15}'::jsonb,
 '{"xp_bonus": 50, "domain": "social"}'::jsonb,
 INTERVAL '24 hours');

-- Count final nodes
-- SELECT COUNT(*) as total_nodes FROM stat_nodes;
-- Should be ~50 nodes
