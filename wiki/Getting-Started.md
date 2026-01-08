# Getting Started with LifeOps

This guide will help you get LifeOps up and running in minutes.

## Prerequisites

Before you begin, make sure you have:
- **Docker** and **Docker Compose** installed
- A computer that can run 24/7 (or a server/Raspberry Pi)
- (Optional) An Oura Ring for health tracking

## Quick Start with Docker

### 1. Clone the Repository

```bash
git clone https://github.com/stephanbirkeland/LifeOps.git
cd LifeOps
```

### 2. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your settings
nano .env  # or use your preferred editor
```

Key settings to configure:
```bash
# Database passwords (change these!)
POSTGRES_PASSWORD=your_secure_password
STATS_POSTGRES_PASSWORD=another_secure_password

# Oura integration (optional)
OURA_CLIENT_ID=your_oura_client_id
OURA_CLIENT_SECRET=your_oura_client_secret
```

### 3. Start the Services

```bash
# Start all services in background
docker compose up -d

# Check they're running
docker compose ps
```

### 4. Verify Installation

```bash
# Check LifeOps API
curl http://localhost:8000/health

# Check Stats API
curl http://localhost:8001/health
```

You should see `{"status": "healthy"}` for both.

### 5. Access the API Documentation

Open your browser to:
- **LifeOps API**: http://localhost:8000/docs
- **Stats API**: http://localhost:8001/docs

## First Steps After Installation

### 1. Create Your Character

Your character is your RPG representation in LifeOps:

```bash
curl -X POST http://localhost:8001/characters \
  -H "Content-Type: application/json" \
  -d '{"name": "Your Name"}'
```

### 2. Set Up Timeline Items

Timeline items are your daily routine activities:

```bash
curl -X POST http://localhost:8000/timeline/items \
  -H "Content-Type: application/json" \
  -d '{
    "code": "morning_stretch",
    "name": "Morning Stretch",
    "category": "morning",
    "anchor_type": "anchor",
    "anchor_reference": "wake_time",
    "offset_minutes": 15,
    "duration_minutes": 10,
    "xp_reward": 25
  }'
```

### 3. Connect Oura Ring (Optional)

See [[Oura Ring Setup]] for detailed instructions.

### 4. Check Your Life Score

```bash
curl http://localhost:8000/gamification/today
```

## Directory Structure

After installation, your LifeOps directory looks like:

```
LifeOps/
├── services/
│   ├── api/          # Main LifeOps API
│   └── stats/        # RPG Stats Service
├── docker-compose.yml
├── .env              # Your configuration
└── ...
```

## Common Commands

```bash
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Restart a specific service
docker compose restart lifeops-api

# Update to latest version
git pull
docker compose up -d --build
```

## Next Steps

- [[Daily Workflow]] - Learn how to use LifeOps daily
- [[Understanding Your Life Score]] - How your score is calculated
- [[Configuration]] - Customize your setup
- [[Oura Ring Setup]] - Connect health tracking

## Troubleshooting

### Services won't start

```bash
# Check for errors
docker compose logs

# Ensure ports aren't in use
lsof -i :8000
lsof -i :8001
```

### Database connection errors

```bash
# Check database is healthy
docker compose exec timescaledb pg_isready
```

### Need more help?

See [[Troubleshooting]] or open an [Issue](https://github.com/stephanbirkeland/LifeOps/issues).
