# Stats Service Architecture

## Executive Summary

A standalone **Stats Service** providing RPG-style character progression for LifeOps and the future ChallengeMode platform. Inspired by Path of Exile's passive skill tree, this system offers deep customization with both automatic stat growth from activities and allocatable points.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Core Concepts](#core-concepts)
3. [Stat Tree Design](#stat-tree-design)
4. [Progression System](#progression-system)
5. [Database Schema](#database-schema)
6. [API Design](#api-design)
7. [Integration Points](#integration-points)
8. [Implementation Phases](#implementation-phases)

---

## System Overview

### Architecture Position

```
┌─────────────────────────────────────────────────────────────────┐
│                      Future: ChallengeMode                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│  │  Challenges  │  │ Communities  │  │   Company    │           │
│  │   Service    │  │   Service    │  │   Accounts   │           │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘           │
│         │                 │                 │                    │
│         └────────────────┬┴─────────────────┘                    │
│                          │                                       │
│                          ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                    STATS SERVICE                           │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │  │
│  │  │  Stat Tree  │  │ Progression │  │  Activity   │        │  │
│  │  │   Engine    │  │   System    │  │   Logger    │        │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘        │  │
│  │                          │                                 │  │
│  │                    [PostgreSQL]                            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                          ▲                                       │
│                          │                                       │
└──────────────────────────┼───────────────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              │                         │
        ┌─────┴─────┐            ┌──────┴──────┐
        │  LifeOps  │            │   Future    │
        │  (Today)  │            │   Clients   │
        └───────────┘            └─────────────┘
```

### Key Principles

1. **Fully Decoupled** - Own database, own API, no direct dependencies
2. **Event-Driven** - Activities logged via events, stats recalculated
3. **Graph-Based Tree** - Nodes and edges, like Path of Exile
4. **Dual Progression** - Auto-growth + allocatable points
5. **Extensible** - New stat types, nodes, and trees without schema changes

---

## Core Concepts

### Stat Categories

```
┌─────────────────────────────────────────────────────────────────┐
│                        STAT HIERARCHY                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CORE ATTRIBUTES (6)          DERIVED STATS (Many)              │
│  ─────────────────            ────────────────────              │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Strength    │──────────────│ Physical Power  │               │
│  │ (STR)       │              │ Endurance       │               │
│  └─────────────┘              │ Lifting Capacity│               │
│                               └─────────────────┘               │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Intelligence│──────────────│ Problem Solving │               │
│  │ (INT)       │              │ Learning Speed  │               │
│  └─────────────┘              │ Memory          │               │
│                               └─────────────────┘               │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Wisdom      │──────────────│ Decision Making │               │
│  │ (WIS)       │              │ Emotional Intel │               │
│  └─────────────┘              │ Self-Awareness  │               │
│                               └─────────────────┘               │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Stamina     │──────────────│ Energy Capacity │               │
│  │ (STA)       │              │ Recovery Rate   │               │
│  └─────────────┘              │ Sleep Quality   │               │
│                               └─────────────────┘               │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Charisma    │──────────────│ Social Influence│               │
│  │ (CHA)       │              │ Networking      │               │
│  └─────────────┘              │ Leadership      │               │
│                               └─────────────────┘               │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Luck        │──────────────│ Opportunity     │               │
│  │ (LCK)       │              │ Timing          │               │
│  └─────────────┘              │ Random Bonuses  │               │
│                               └─────────────────┘               │
│                                                                  │
│  SKILLS (Unlockable)          KEYSTONES (Major Effects)         │
│  ───────────────────          ─────────────────────────         │
│  ┌─────────────┐              ┌─────────────────┐               │
│  │ Deep Focus  │              │ Early Bird      │               │
│  │ Speed Read  │              │ Night Owl       │               │
│  │ Cold Shower │              │ Iron Will       │               │
│  │ Meditation  │              │ Social Butterfly│               │
│  └─────────────┘              └─────────────────┘               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Node Types

| Type | Description | Example |
|------|-------------|---------|
| **Core Attribute** | Base stats, foundation of all progression | Strength, Intelligence |
| **Derived Stat** | Calculated from core attributes + bonuses | Physical Power = STR × 1.5 + bonuses |
| **Minor Node** | Small bonuses (+1 to stat, +2% to derived) | +1 Strength |
| **Notable Node** | Larger bonuses, named abilities | "Iron Grip" - +5 STR, +10% Endurance |
| **Keystone Node** | Major effects with trade-offs | "Early Bird" - +20% morning XP, -10% night XP |
| **Skill Node** | Unlockable abilities | "Deep Focus" - 2hr focus sessions unlock |

### Activity → Stat Mapping

| Activity Domain | Primary Stat | Secondary Stats |
|-----------------|--------------|-----------------|
| Physical Exercise | Strength | Stamina, Wisdom |
| Sleep/Recovery | Stamina | Wisdom, Luck |
| Learning/Study | Intelligence | Wisdom |
| Work Tasks | Intelligence | Charisma |
| Social Events | Charisma | Luck, Wisdom |
| Meditation | Wisdom | Stamina, Intelligence |
| Random Acts | Luck | All (small) |

---

## Stat Tree Design

### Graph Structure

```
                                    [Starting Node]
                                          │
                    ┌─────────────────────┼─────────────────────┐
                    │                     │                     │
                    ▼                     ▼                     ▼
              [STR Path]            [INT Path]            [WIS Path]
                    │                     │                     │
         ┌────┬────┼────┬────┐   ┌───┬───┼───┬───┐    ┌───┬───┼───┬───┐
         ▼    ▼    ▼    ▼    ▼   ▼   ▼   ▼   ▼   ▼    ▼   ▼   ▼   ▼   ▼
        [+1] [+1] [Notable] ...  ...                   ...
         │         │
         └────┬────┘
              │
              ▼
         [Keystone]
```

### Path of Exile-Inspired Features

1. **Interconnected Paths** - Can reach STR nodes via INT path (longer route)
2. **Cluster Jewels** (Future) - Custom node clusters users can socket
3. **Ascendancy Classes** (Future) - Specialization trees
4. **Respec Cost** - Points can be reallocated but costs resources

### Initial Tree: "Life Mastery"

```
Nodes: ~50 initial (expandable to 500+)

Center: [Origin]
├── STR Branch (12 nodes)
│   ├── 8 minor (+1 STR, +2% Physical)
│   ├── 3 notable (Iron Grip, Endurance Master, Titan's Strength)
│   └── 1 keystone (Unstoppable Force)
│
├── INT Branch (12 nodes)
│   ├── 8 minor (+1 INT, +2% Learning)
│   ├── 3 notable (Quick Learner, Problem Solver, Memory Palace)
│   └── 1 keystone (Analytical Mind)
│
├── WIS Branch (12 nodes)
│   ├── 8 minor (+1 WIS, +2% Decision)
│   ├── 3 notable (Mindfulness, Emotional Mastery, Clear Vision)
│   └── 1 keystone (Enlightened)
│
├── STA Branch (12 nodes)
│   ├── 8 minor (+1 STA, +2% Energy)
│   ├── 3 notable (Deep Sleep, Recovery Pro, Boundless Energy)
│   └── 1 keystone (Tireless)
│
├── CHA Branch (12 nodes)
│   ├── 8 minor (+1 CHA, +2% Social)
│   ├── 3 notable (Networker, Leader, Influencer)
│   └── 1 keystone (Social Butterfly)
│
└── LCK Branch (8 nodes)
    ├── 5 minor (+1 LCK, +2% Opportunity)
    ├── 2 notable (Fortune Favors, Perfect Timing)
    └── 1 keystone (Destiny's Child)
```

---

## Progression System

### Dual Progression Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    PROGRESSION SOURCES                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. PASSIVE GROWTH (Automatic)                                  │
│  ─────────────────────────────                                  │
│                                                                  │
│  Activity Logged ──► Stat XP Gained ──► Stat Levels Up          │
│                                                                  │
│  Example:                                                        │
│  • Log "Gym Session" (1hr weights)                              │
│  • +50 STR XP, +20 STA XP                                       │
│  • When STR XP reaches threshold → STR increases                │
│                                                                  │
│  ─────────────────────────────────────────────────────────────  │
│                                                                  │
│  2. ALLOCATABLE POINTS (Choice)                                 │
│  ──────────────────────────────                                 │
│                                                                  │
│  Character Level Up ──► Earn Stat Points ──► Allocate to Tree  │
│                                                                  │
│  Example:                                                        │
│  • Reach Character Level 5                                      │
│  • Earn 3 Stat Points                                           │
│  • Allocate to tree nodes (unlock path to Keystone)             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### XP and Leveling

**Character XP** (from LifeOps/ChallengeMode):
- Completing challenges
- Daily Life Score bonus
- Achievement unlocks
- Streak milestones

**Stat XP** (per-stat progression):
- Each core attribute has its own XP pool
- Activities grant XP to relevant stats
- XP thresholds for stat level-ups

```python
# Stat XP thresholds (exponential)
def xp_for_stat_level(level: int) -> int:
    return int(100 * (1.5 ** (level - 1)))

# Level 1: 100 XP
# Level 2: 150 XP
# Level 3: 225 XP
# Level 10: 3,844 XP
# Level 20: 221,073 XP
```

### Point Allocation

| Source | Points Earned |
|--------|---------------|
| Character Level Up | 1 point per level |
| Major Achievement | 1-3 bonus points |
| Challenge Completion | 0-2 points (difficulty based) |
| Seasonal Reset | Respec tokens |

---

## Database Schema

### Core Tables

```sql
-- Characters (one per user)
CREATE TABLE characters (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL UNIQUE,  -- External user reference
    name            TEXT,

    -- Character progression
    level           INTEGER DEFAULT 1,
    total_xp        BIGINT DEFAULT 0,

    -- Allocatable points
    stat_points     INTEGER DEFAULT 0,
    respec_tokens   INTEGER DEFAULT 1,

    -- Timestamps
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Core attribute values (per character)
CREATE TABLE character_stats (
    character_id    UUID REFERENCES characters(id) ON DELETE CASCADE,
    stat_code       TEXT NOT NULL,  -- 'STR', 'INT', etc.

    -- Base value (from passive growth)
    base_value      INTEGER DEFAULT 10,
    stat_xp         BIGINT DEFAULT 0,

    -- Bonus from tree allocations
    allocated_bonus INTEGER DEFAULT 0,

    -- Calculated total
    total_value     INTEGER GENERATED ALWAYS AS (base_value + allocated_bonus) STORED,

    PRIMARY KEY (character_id, stat_code)
);

-- Stat tree node definitions (game design data)
CREATE TABLE stat_nodes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    description     TEXT,

    -- Node classification
    node_type       TEXT NOT NULL,  -- 'minor', 'notable', 'keystone', 'skill'
    tree_branch     TEXT,           -- 'STR', 'INT', etc.

    -- Visual position (for tree rendering)
    position_x      FLOAT DEFAULT 0,
    position_y      FLOAT DEFAULT 0,

    -- Requirements
    required_points INTEGER DEFAULT 1,  -- Points to allocate
    prerequisite_nodes UUID[] DEFAULT '{}',  -- Must have these first

    -- Effects (JSONB for flexibility)
    effects         JSONB DEFAULT '[]',

    -- Metadata
    icon            TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Node connections (edges in the tree graph)
CREATE TABLE stat_node_edges (
    from_node_id    UUID REFERENCES stat_nodes(id),
    to_node_id      UUID REFERENCES stat_nodes(id),
    bidirectional   BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (from_node_id, to_node_id)
);

-- Character's allocated nodes
CREATE TABLE character_nodes (
    character_id    UUID REFERENCES characters(id) ON DELETE CASCADE,
    node_id         UUID REFERENCES stat_nodes(id),
    allocated_at    TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (character_id, node_id)
);

-- Activity log (events that grant stat XP)
CREATE TABLE activity_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    character_id    UUID REFERENCES characters(id),

    -- Activity details
    activity_type   TEXT NOT NULL,
    activity_data   JSONB DEFAULT '{}',
    source          TEXT NOT NULL,  -- 'lifeops', 'challengemode', etc.
    source_ref      TEXT,           -- External reference ID

    -- XP granted
    xp_grants       JSONB DEFAULT '{}',  -- {"STR": 50, "STA": 20}

    -- Timestamps
    activity_time   TIMESTAMPTZ NOT NULL,
    logged_at       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX idx_activity_log_character ON activity_log(character_id, activity_time DESC);

-- Derived stats definitions
CREATE TABLE derived_stats (
    code            TEXT PRIMARY KEY,
    name            TEXT NOT NULL,
    description     TEXT,

    -- Formula (evaluated at runtime)
    formula         TEXT NOT NULL,  -- e.g., "STR * 1.5 + INT * 0.5"

    -- Which core stats affect this
    source_stats    TEXT[] DEFAULT '{}',

    is_active       BOOLEAN DEFAULT TRUE
);

-- Skill definitions (unlockable abilities)
CREATE TABLE skills (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    description     TEXT,

    -- Unlock requirements
    required_node_id UUID REFERENCES stat_nodes(id),
    stat_requirements JSONB DEFAULT '{}',  -- {"STR": 20, "STA": 15}

    -- Skill effects
    effects         JSONB DEFAULT '{}',
    cooldown        INTERVAL,

    is_active       BOOLEAN DEFAULT TRUE
);

-- Character's unlocked skills
CREATE TABLE character_skills (
    character_id    UUID REFERENCES characters(id) ON DELETE CASCADE,
    skill_id        UUID REFERENCES skills(id),
    unlocked_at     TIMESTAMPTZ DEFAULT NOW(),
    times_used      INTEGER DEFAULT 0,
    last_used       TIMESTAMPTZ,
    PRIMARY KEY (character_id, skill_id)
);
```

### Effect System (JSONB Schema)

```json
// Node effects examples
{
  "effects": [
    {"type": "stat_bonus", "stat": "STR", "value": 1},
    {"type": "stat_bonus", "stat": "STR", "value_percent": 5},
    {"type": "derived_bonus", "derived": "physical_power", "value_percent": 10},
    {"type": "xp_multiplier", "domain": "fitness", "value": 1.1},
    {"type": "unlock_skill", "skill_code": "deep_focus"}
  ]
}

// Keystone effects (with trade-offs)
{
  "effects": [
    {"type": "stat_bonus", "stat": "INT", "value_percent": 30},
    {"type": "stat_penalty", "stat": "STR", "value_percent": -15},
    {"type": "special", "code": "analytical_mind", "description": "Learning activities grant 50% more XP"}
  ]
}
```

---

## API Design

### Endpoints

```
Stats Service API (Port 8001)

/health                     GET     Health check

# Character Management
/characters                 POST    Create character for user
/characters/{user_id}       GET     Get character by user ID
/characters/{id}/stats      GET     Get all stats for character
/characters/{id}/tree       GET     Get allocated tree nodes

# Stat Tree
/tree                       GET     Get full tree definition
/tree/nodes                 GET     List all nodes
/tree/nodes/{code}          GET     Get node details
/tree/allocate              POST    Allocate points to nodes
/tree/respec                POST    Reset allocations (costs token)

# Activities
/activities                 POST    Log activity (grants XP)
/activities/batch           POST    Log multiple activities
/activities/{character_id}  GET     Get activity history

# Derived Stats
/derived/{character_id}     GET     Get all derived stat values

# Skills
/skills                     GET     List all skills
/skills/{character_id}      GET     Get character's unlocked skills
/skills/{character_id}/use  POST    Use a skill (if applicable)

# Leaderboards (future)
/leaderboards/stats         GET     Top characters by stat
/leaderboards/level         GET     Top characters by level
```

### Example Requests

**Log Activity (from LifeOps):**
```json
POST /activities
{
  "user_id": "uuid-from-lifeops",
  "activity_type": "gym_session",
  "activity_data": {
    "duration_minutes": 60,
    "type": "strength_training",
    "exercises": ["bench_press", "squats", "deadlift"]
  },
  "source": "lifeops",
  "source_ref": "habit_log_123",
  "activity_time": "2025-01-08T07:30:00Z"
}

Response:
{
  "success": true,
  "xp_granted": {
    "STR": 75,
    "STA": 30
  },
  "stat_level_ups": ["STR"],  // If threshold crossed
  "new_stats": {
    "STR": {"base": 15, "total": 18, "xp": 150, "xp_to_next": 225}
  }
}
```

**Allocate Tree Points:**
```json
POST /tree/allocate
{
  "character_id": "uuid",
  "node_codes": ["str_minor_1", "str_minor_2", "iron_grip"]
}

Response:
{
  "success": true,
  "points_spent": 3,
  "points_remaining": 2,
  "nodes_allocated": ["str_minor_1", "str_minor_2", "iron_grip"],
  "stat_changes": {
    "STR": {"before": 15, "after": 20}
  },
  "new_effects": [
    {"type": "notable", "name": "Iron Grip", "description": "+5 STR, +10% Endurance"}
  ]
}
```

**Get Character Overview:**
```json
GET /characters/{user_id}

Response:
{
  "id": "char-uuid",
  "user_id": "user-uuid",
  "name": "Adventurer",
  "level": 7,
  "total_xp": 8500,
  "xp_to_next_level": 10000,
  "stat_points": 2,
  "respec_tokens": 1,
  "stats": {
    "STR": {"base": 15, "allocated": 5, "total": 20, "xp": 1250},
    "INT": {"base": 12, "allocated": 2, "total": 14, "xp": 800},
    "WIS": {"base": 14, "allocated": 0, "total": 14, "xp": 950},
    "STA": {"base": 18, "allocated": 3, "total": 21, "xp": 1500},
    "CHA": {"base": 10, "allocated": 0, "total": 10, "xp": 400},
    "LCK": {"base": 8, "allocated": 0, "total": 8, "xp": 200}
  },
  "allocated_nodes": 10,
  "unlocked_skills": ["deep_focus"],
  "derived_stats": {
    "physical_power": 35,
    "learning_speed": 18,
    "energy_capacity": 42
  }
}
```

---

## Integration Points

### LifeOps → Stats Service

```
LifeOps Events that trigger stat XP:

┌────────────────────┬─────────────────────────┬──────────────────┐
│ LifeOps Event      │ Activity Type           │ XP Grants        │
├────────────────────┼─────────────────────────┼──────────────────┤
│ Oura sleep sync    │ sleep_tracked           │ STA +20-50       │
│ High sleep score   │ quality_sleep           │ STA +30, WIS +10 │
│ Gym habit logged   │ gym_session             │ STR +50-100      │
│ Work hours logged  │ work_completed          │ INT +20-50       │
│ Early wake         │ early_rise              │ STA +15, WIS +10 │
│ Streak maintained  │ streak_maintained       │ WIS +25          │
│ Achievement unlock │ achievement_earned      │ Varies by type   │
│ Life Score 90+     │ excellent_day           │ All +10          │
└────────────────────┴─────────────────────────┴──────────────────┘
```

### Future: ChallengeMode → Stats Service

```
ChallengeMode Events:

┌────────────────────┬─────────────────────────┬──────────────────┐
│ Challenge Type     │ Activity Type           │ XP Grants        │
├────────────────────┼─────────────────────────┼──────────────────┤
│ Fitness challenge  │ challenge_fitness       │ STR, STA         │
│ Learning challenge │ challenge_learning      │ INT, WIS         │
│ Social challenge   │ challenge_social        │ CHA, LCK         │
│ Company challenge  │ challenge_work          │ INT, CHA         │
│ Community event    │ community_participation │ CHA +50          │
│ Challenge created  │ challenge_created       │ INT +20, CHA +10 │
└────────────────────┴─────────────────────────┴──────────────────┘
```

### Event Flow

```
┌─────────────┐     Event Bus (MQTT/Kafka)     ┌──────────────┐
│   LifeOps   │────────────────────────────────│ Stats Service│
│             │   topic: stats/activity        │              │
│ Gym logged  │──────────────────────────────▶│ Process XP   │
│             │                                │ Update stats │
│             │◀──────────────────────────────│ Level up!    │
│ Show notif  │   topic: stats/events          │              │
└─────────────┘                                └──────────────┘
```

---

## Implementation Phases

### Phase 1: Core Service (Week 1-2)

**Deliverables:**
- Stats Service scaffolding (FastAPI)
- Database schema (PostgreSQL)
- Character CRUD
- Core stats tracking
- Activity logging endpoint
- Basic stat XP system

**Endpoints:**
- `/characters` - Create/Get
- `/characters/{id}/stats` - Get stats
- `/activities` - Log activity

### Phase 2: Stat Tree Engine (Week 3-4)

**Deliverables:**
- Tree node definitions
- Graph traversal (can reach node?)
- Point allocation logic
- Respec functionality
- Initial tree data (~50 nodes)

**Endpoints:**
- `/tree` - Get tree
- `/tree/allocate` - Allocate points
- `/tree/respec` - Reset

### Phase 3: LifeOps Integration (Week 5)

**Deliverables:**
- Event publishing from LifeOps
- Stats Service event consumption
- LifeOps UI showing character stats
- Activity → XP mapping configuration

### Phase 4: Derived Stats & Skills (Week 6)

**Deliverables:**
- Derived stat formulas
- Skill definitions
- Skill unlock logic
- Effect application system

### Phase 5: Polish & Expand (Ongoing)

**Deliverables:**
- More tree nodes
- Balancing
- Leaderboards
- Tree visualization UI
- ChallengeMode preparation

---

## Technical Notes

### Service Configuration

```yaml
# stats-service config
service:
  name: stats-service
  port: 8001

database:
  url: postgresql://stats:password@localhost:5433/stats
  pool_size: 10

event_bus:
  type: mqtt  # or kafka for scale
  broker: localhost:1883
  topics:
    activities: stats/activities
    events: stats/events

xp_config:
  level_base: 1000
  level_multiplier: 1.5
  stat_level_base: 100
  stat_level_multiplier: 1.5
```

### Docker Addition

```yaml
# Add to LifeOps docker-compose.yml
stats-service:
  build: ./services/stats
  container_name: lifeops-stats
  environment:
    DATABASE_URL: postgresql://stats:${STATS_DB_PASSWORD}@stats-db:5432/stats
    MQTT_BROKER: mosquitto
  ports:
    - "8001:8001"
  depends_on:
    - stats-db
    - mosquitto

stats-db:
  image: postgres:15
  container_name: lifeops-stats-db
  environment:
    POSTGRES_USER: stats
    POSTGRES_PASSWORD: ${STATS_DB_PASSWORD}
    POSTGRES_DB: stats
  volumes:
    - ./stats-db/data:/var/lib/postgresql/data
  ports:
    - "5433:5432"
```

---

## Summary

This architecture provides:

1. **Standalone service** - Clean separation, own database
2. **PoE-inspired depth** - Graph-based tree with 50+ initial nodes
3. **Dual progression** - Auto-growth + choice
4. **Extensibility** - JSONB effects, easy to add nodes/stats
5. **Future-proof** - Ready for ChallengeMode integration

Ready to implement?
