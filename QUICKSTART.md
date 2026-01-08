# LifeOps Quick Start Guide

Get LifeOps running on your Arch Linux desktop in minutes.

## Prerequisites

```bash
# Install Docker
sudo pacman -S docker docker-compose

# Start Docker service
sudo systemctl enable docker
sudo systemctl start docker

# Add yourself to docker group (logout/login after)
sudo usermod -aG docker $USER
```

## 1. Configure Environment

```bash
cd ~/workspace/personal/LifeOps

# Create environment file from template
cp .env.example .env

# Edit with your values
nano .env
```

**Required for Oura integration:**

1. Go to https://cloud.ouraring.com/personal-access-tokens
2. Create a new Personal Access Token
3. Add to `.env`: `OURA_ACCESS_TOKEN=your_token_here`

## 2. Start Services

```bash
# Start core infrastructure
docker compose up -d timescaledb stats-db mosquitto

# Wait for databases to be ready (~10 seconds)
sleep 10

# Start LifeOps API and Stats Service
docker compose up -d lifeops-api stats-api

# Check all services are running
docker compose ps
```

## 3. Verify Installation

```bash
# Check LifeOps API health
curl http://localhost:8000/health

# Check Stats Service health
curl http://localhost:8001/health

# Check Oura connection
curl http://localhost:8000/oura/status
```

## 4. Sync Your First Data

```bash
# Sync last 7 days of Oura data
curl -X POST "http://localhost:8000/oura/sync"

# Get today's Life Score
curl http://localhost:8000/api/today
```

## 5. Access API Documentation

- LifeOps API: http://localhost:8000/docs
- Stats Service: http://localhost:8001/docs

## Quick API Reference

### LifeOps API (Port 8000)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/today` | GET | Today's Life Score, XP, streaks |
| `/api/history?days=30` | GET | Score history |
| `/api/xp` | GET | Current XP and level |
| `/api/achievements` | GET | All achievements |
| `/oura/sync` | POST | Sync Oura data |
| `/oura/today` | GET | Today's Oura scores |
| `/user/profile` | GET | User profile |
| `/user/goals` | GET/PATCH | User goals |

### Stats Service (Port 8001)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/characters` | POST | Create character |
| `/characters/user/{user_id}` | GET | Get character by user |
| `/characters/{id}/full` | GET | Full character details |
| `/stats/{character_id}` | GET | Get detailed stats |
| `/tree` | GET | Get skill tree structure |
| `/tree/allocate` | POST | Allocate tree nodes |
| `/tree/respec` | POST | Reset allocations |
| `/activities` | POST | Log activity (grants XP) |
| `/activities/types` | GET | Available activity types |

## Example: Get Today's Score

```bash
curl -s http://localhost:8000/api/today | python -m json.tool
```

Response:
```json
{
  "date": "2025-01-08",
  "life_score": 78.5,
  "domains": {
    "sleep": 82.0,
    "activity": 75.0,
    "worklife": 80.0,
    "habits": 70.0
  },
  "xp": {
    "total_xp": 1250,
    "level": 2,
    "progress_to_next": 25.0,
    "today_xp": 785
  },
  "streaks": {
    "morning_victory": 3,
    "gym_chain": 1
  }
}
```

## Optional: Add Home Assistant

```bash
# Start Home Assistant (for future sensor integration)
docker compose up -d homeassistant

# Access at http://localhost:8123
```

## Optional: Database Admin UI

```bash
# Start Adminer for database inspection
docker compose --profile dev up -d adminer

# Access at http://localhost:8080
# Server: timescaledb
# Username: lifeops
# Password: (from .env)
# Database: lifeops
```

## Logs & Debugging

```bash
# View API logs
docker compose logs -f lifeops-api

# View all logs
docker compose logs -f

# Restart a service
docker compose restart lifeops-api
```

## Stop Services

```bash
# Stop all services
docker compose down

# Stop and remove data (fresh start)
docker compose down -v
```

## Next Steps

1. **Set up Tailscale** for remote access
2. **Order hardware** from AliExpress (see HARDWARE.md)
3. **Configure Home Assistant** when sensors arrive
4. **Build iOS app** (future phase)

---

See [SETUP.md](SETUP.md) for complete installation guide.
