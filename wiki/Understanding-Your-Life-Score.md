# Understanding Your Life Score

Your Life Score is a daily measure of how well you're living according to your goals. It combines multiple aspects of your life into a single, actionable number.

## Score Overview

Your Life Score ranges from **0 to 100** and updates throughout the day as new data comes in.

| Score Range | Rating | What It Means |
|-------------|--------|---------------|
| 90-100 | Excellent | Outstanding day across all domains |
| 80-89 | Great | Solid performance, minor areas for improvement |
| 70-79 | Good | Meeting most goals, room to grow |
| 60-69 | Fair | Some domains need attention |
| Below 60 | Needs Work | Multiple areas require focus |

## The Four Domains

Your Life Score is calculated from four weighted domains:

### 1. Sleep Score (30%)

Based on your Oura Ring data and sleep habits.

**Components:**
- **Oura Sleep Score** (60%): Direct from Oura Ring
- **Wake Time Consistency** (25%): How close to your target wake time
- **Pre-Bed Routine** (15%): Screens off, in bed on time

**Tips to Improve:**
- Maintain consistent wake time (even weekends)
- Put screens away 30 minutes before bed
- Go to bed at your target time

### 2. Activity Score (25%)

Measures your physical activity and exercise.

**Components:**
- **Oura Activity Score** (40%): Movement and exercise from Oura
- **Gym Sessions** (40%): Weekly gym attendance vs. target
- **Daily Steps** (20%): Step count thresholds

**Step Scoring:**
| Steps | Score |
|-------|-------|
| 10,000+ | 100 |
| 7,000+ | 90 |
| 5,000+ | 70 |
| 3,000+ | 40 |
| Below 3,000 | Proportional |

**Tips to Improve:**
- Hit your weekly gym target
- Take walking breaks during work
- Track steps consistently

### 3. Work-Life Score (25%)

Ensures healthy boundaries between work and personal time.

**Components:**
- **Work Hours** (40%): Daily hours worked
- **Cutoff Time** (35%): When you stop working
- **Weekend Recovery** (25%): Avoiding work on weekends

**Work Hours Scoring:**
| Hours | Score |
|-------|-------|
| ≤8 | 100 |
| 8-9 | 85 |
| 9-10 | 60 |
| 10-11 | 30 |
| >11 | 0 |

**Tips to Improve:**
- Set a hard stop time for work
- Protect your weekends
- Take breaks during the day

### 4. Habits Score (20%)

Tracks daily habits and screen time.

**Components:**
- **Screen Time** (50%): Non-work screen usage
- **Daily Checklist** (50%): Completing timeline items

**Screen Time Scoring:**
| Hours | Score |
|-------|-------|
| <2 | 100 |
| 2-3 | 80 |
| 3-4 | 60 |
| 4-5 | 30 |
| >5 | 0 |

**Tips to Improve:**
- Set app limits on your phone
- Complete your daily timeline items
- Be intentional about screen usage

## XP and Bonuses

Your Life Score also affects XP earned:

**Base XP**: `Life Score × 10`

**Bonus XP Triggers:**
| Achievement | Bonus XP |
|-------------|----------|
| Life Score 95+ | +500 |
| Life Score 90+ | +300 |
| Perfect Oura Sleep (100) | +200 |
| Excellent Sleep (85+) | +100 |
| 10,000 Steps | +100 |

## Viewing Your Score

### API
```bash
# Get today's complete status
curl http://localhost:8000/gamification/today

# Response includes:
# - life_score: Your current score
# - domains: Individual domain scores
# - xp: XP earned today
# - streaks: Active streaks
```

### Daily Breakdown

The `/gamification/today` endpoint returns:
```json
{
  "date": "2025-01-08",
  "life_score": 82.5,
  "domains": {
    "sleep": 88.0,
    "activity": 75.0,
    "worklife": 85.0,
    "habits": 78.0
  },
  "xp": {
    "total_xp": 45230,
    "level": 6,
    "today_xp": 825
  }
}
```

## Historical Data

Track your score over time:
```bash
# Get scores for date range
curl "http://localhost:8000/gamification/history?start=2025-01-01&end=2025-01-07"
```

## Customizing Weights

The default weights can be adjusted based on your priorities. Edit your configuration to change the emphasis on different domains.

Default weights:
- Sleep: 30%
- Activity: 25%
- Work-Life: 25%
- Habits: 20%

---

**Next**: [[Timeline and Routines]] - Managing your daily schedule
