# Frequently Asked Questions

## General

### What is LifeOps?

LifeOps is a self-hosted personal life management system that helps you:
- Track habits and routines
- Monitor health data from Oura Ring
- Gamify personal development with RPG mechanics
- Manage your daily schedule

### Is LifeOps free?

Yes, LifeOps is free for personal, non-commercial use. See the [LICENSE](https://github.com/stephanbirkeland/LifeOps/blob/main/LICENSE) for details.

### What data does LifeOps collect?

LifeOps only collects data you explicitly provide or authorize (like Oura Ring sync). All data is stored locally on your own server - nothing is sent to external services.

### Can I use LifeOps without an Oura Ring?

Yes! The Oura integration is optional. You can manually enter health data or use LifeOps purely for habit tracking and gamification.

## Installation

### What are the system requirements?

- **Minimum**: 1GB RAM, 2GB storage
- **Recommended**: 2GB+ RAM, 10GB+ storage
- **OS**: Any system that runs Docker (Linux, macOS, Windows)
- A Raspberry Pi 4 works great for 24/7 operation

### Can I run LifeOps on a Raspberry Pi?

Yes! LifeOps is designed to be CPU-efficient. A Raspberry Pi 4 with 2GB+ RAM works well.

### How do I update LifeOps?

```bash
cd LifeOps
git pull
docker compose up -d --build
```

## Life Score

### How is my Life Score calculated?

Your Life Score is a weighted average of four domains:
- **Sleep** (30%): Oura sleep score + wake time consistency
- **Activity** (25%): Oura activity score + gym sessions + steps
- **Work-Life** (25%): Work hours + cutoff time + weekend recovery
- **Habits** (20%): Screen time + daily checklist completion

### What's a good Life Score?

| Score | Rating |
|-------|--------|
| 90-100 | Excellent |
| 80-89 | Great |
| 70-79 | Good |
| 60-69 | Fair |
| Below 60 | Needs improvement |

### Why did my score change?

Your score updates based on:
- New Oura data syncing
- Completing timeline items
- Daily recalculation at midnight

## RPG System

### How do stats work?

You have 6 core stats:
- **STR** (Strength): Physical power from gym/exercise
- **INT** (Intelligence): Learning from reading/courses
- **WIS** (Wisdom): Mindfulness from meditation/reflection
- **STA** (Stamina): Endurance from sleep/recovery
- **CHA** (Charisma): Social skills from interactions
- **LCK** (Luck): Random bonuses

### How do I gain XP?

XP is earned by:
- Completing timeline items
- Achieving high Life Scores
- Unlocking achievements
- Maintaining streaks

### What are stat points?

Stat points are earned when you level up. Use them to allocate nodes in your skill tree, providing permanent bonuses.

### Can I reset my skill tree?

Yes, you can use a Respec Token to reset all allocated nodes and get your points back. Tokens are earned through achievements.

## Timeline

### How do time anchors work?

Time anchors are reference points your schedule builds around:
- `wake_time`: When you wake up (from Oura or manual)
- `work_start`: When your work day begins
- `work_end`: When your work day ends
- `bedtime`: Your target bedtime

Timeline items can be scheduled relative to these anchors.

### What happens if I miss a timeline item?

Missed items don't complete automatically. If you have a streak, missing an item will break it (unless you have freeze tokens).

### Can I skip items without breaking my streak?

Yes! Use "skip" instead of letting items expire. Skipped items don't count as completing or breaking a streak - they're marked as intentionally skipped.

## Integrations

### How do I connect my Oura Ring?

1. Create an Oura developer account at https://cloud.ouraring.com
2. Create an application to get Client ID and Secret
3. Add credentials to your `.env` file
4. Restart LifeOps and authorize via the API

See [[Oura Ring Setup]] for detailed instructions.

### Will you add support for other wearables?

Future integrations planned:
- Apple Health
- Google Fit
- Fitbit
- Withings

## Troubleshooting

### My Life Score is stuck at 0

- Check if Oura is syncing: `GET /oura/status`
- Manually trigger a sync: `POST /oura/sync`
- Check the logs: `docker compose logs lifeops-api`

### Streaks aren't updating

Streaks update when you complete items. Check:
- Is the item configured with a `streak_category`?
- Did you complete the item (not just skip it)?

### API returns errors

Check the logs for details:
```bash
docker compose logs -f lifeops-api
```

Common issues:
- Database not ready (wait a few seconds after startup)
- Invalid request format (check API docs)
- Missing required fields

---

Still have questions? Open a [Discussion](https://github.com/stephanbirkeland/LifeOps/discussions).
