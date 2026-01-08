# RPG Stats System

LifeOps gamifies your personal development using an RPG-inspired character system. Grow your stats, level up, and unlock abilities as you improve your real-life habits.

## Your Character

When you start LifeOps, you create a character that represents you. Your character has:
- **Level**: Overall progression (starts at 1)
- **Stats**: Six core attributes
- **Stat Points**: Spend in the skill tree
- **XP**: Experience points toward next level

## The Six Stats

| Stat | Code | Theme | Real-Life Activities |
|------|------|-------|---------------------|
| **Strength** | STR | Physical power | Gym, weightlifting, physical labor |
| **Intelligence** | INT | Learning | Reading, courses, problem-solving |
| **Wisdom** | WIS | Mindfulness | Meditation, reflection, journaling |
| **Stamina** | STA | Endurance | Sleep quality, recovery, health habits |
| **Charisma** | CHA | Social | Social events, networking, communication |
| **Luck** | LCK | Fortune | Random bonuses, rare achievements |

## How Stats Grow

Stats grow in two ways:

### 1. Passive Growth (XP)
Activities automatically grant stat XP:

| Activity | Stats Gained |
|----------|-------------|
| Complete gym session | STR +50, STA +20 |
| Morning stretch | STR +10, WIS +5 |
| Meditation | WIS +30, STA +10 |
| Read for 30 min | INT +25 |
| Social event | CHA +40 |
| Good sleep (85+) | STA +30 |

### 2. Allocated Bonuses (Skill Tree)
Spend stat points in the skill tree for permanent bonuses. See [[Skill Tree Guide]].

## Leveling Up

### Character Level

Your character level is based on total XP:

| Level | Total XP Required |
|-------|-------------------|
| 1 | 0 |
| 2 | 1,000 |
| 3 | 4,000 |
| 5 | 25,000 |
| 10 | 100,000 |
| 20 | 400,000 |

**Formula**: `XP = 1000 × level²`

### Stat Levels

Each stat also has its own level:
- Base level: 10
- Each stat levels independently based on XP in that stat
- Higher stat levels require exponentially more XP

## Stat Points

Earn stat points when you level up:

| Level Type | Points Earned |
|------------|---------------|
| Regular level | 1 point |
| Every 5th level (5, 10, 15...) | 2 points |
| Every 10th level (10, 20, 30...) | 3 points |

Spend these points in your [[Skill Tree Guide|skill tree]] for permanent bonuses.

## Derived Stats

Some stats are calculated from your core stats:

| Derived Stat | Formula | Meaning |
|--------------|---------|---------|
| **Power** | STR×0.6 + INT×0.4 | Overall capability |
| **Resilience** | STA×0.7 + WIS×0.3 | Recovery ability |
| **Influence** | CHA×0.6 + INT×0.3 + LCK×0.1 | Social impact |
| **Fortune** | LCK×0.8 + WIS×0.2 | Chance for bonuses |
| **Focus** | INT×0.5 + WIS×0.5 | Concentration |
| **Vitality** | STA×0.5 + STR×0.3 + WIS×0.2 | Health capacity |

## Viewing Your Stats

### API Endpoints

```bash
# Get your character with stats
curl http://localhost:8001/characters/{character_id}

# Get detailed stats breakdown
curl http://localhost:8001/characters/{character_id}/stats
```

### Response Example
```json
{
  "id": "uuid",
  "name": "Your Name",
  "level": 6,
  "total_xp": 45230,
  "stat_points": 3,
  "stats": {
    "STR": {"base": 14, "allocated": 2, "total": 16},
    "INT": {"base": 12, "allocated": 1, "total": 13},
    "WIS": {"base": 11, "allocated": 0, "total": 11},
    "STA": {"base": 15, "allocated": 3, "total": 18},
    "CHA": {"base": 10, "allocated": 0, "total": 10},
    "LCK": {"base": 10, "allocated": 0, "total": 10}
  }
}
```

## XP Sources

| Source | XP Range | Notes |
|--------|----------|-------|
| Timeline item completion | 10-50 | Per item |
| Daily Life Score | 600-1000 | Based on score |
| Life Score 90+ | +300 | Bonus |
| Life Score 95+ | +500 | Bonus |
| Excellent sleep | +100 | Oura 85+ |
| Perfect sleep | +200 | Oura 100 |
| 10k steps | +100 | Daily |
| Achievements | 100-1000 | Varies |

## Tips for Balanced Growth

1. **Don't neglect any stat** - All stats contribute to derived stats
2. **Focus on your goals** - Prioritize stats that align with your objectives
3. **Use the skill tree strategically** - Hybrid nodes offer unique bonuses
4. **Maintain streaks** - Consistent activity grants more XP over time
5. **Complete daily timeline** - Regular completions add up

## Respec

Made a mistake with stat point allocation? Use a Respec Token to:
- Reset all skill tree allocations
- Get all spent points back
- Reallocate based on new strategy

Respec Tokens are earned through:
- Certain achievements
- Major milestones
- Special events

---

**Next**: [[Skill Tree Guide]] - Spending your stat points
