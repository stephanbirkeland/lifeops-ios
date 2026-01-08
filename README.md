# LifeOps

[![Python 3.12+](https://img.shields.io/badge/python-3.12+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.109+-green.svg)](https://fastapi.tiangolo.com/)
[![License: Non-Commercial](https://img.shields.io/badge/License-Non--Commercial-red.svg)](LICENSE)
[![Docker](https://img.shields.io/badge/Docker-ready-blue.svg)](https://www.docker.com/)
[![CI](https://github.com/stephanbirkeland/LifeOps/actions/workflows/ci.yml/badge.svg)](https://github.com/stephanbirkeland/LifeOps/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/stephanbirkeland/LifeOps/branch/main/graph/badge.svg)](https://codecov.io/gh/stephanbirkeland/LifeOps)
[![Code style: ruff](https://img.shields.io/badge/code%20style-ruff-000000.svg)](https://github.com/astral-sh/ruff)
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://github.com/pre-commit/pre-commit)

A privacy-first, self-hosted personal life management system with gamification. Control all aspects of your private life from ONE unified app.

## Vision

LifeOps is a private, personal life management system designed to:

- **Unify** all your devices and ecosystems (Apple, Google, Samsung, Oura, smart home)
- **Gamify** your habits with RPG-style stats, XP, and skill trees
- **Automate** your daily routines with smart scheduling
- **Respect** your privacy - all data stays under your control

> Technology should improve life, not consume it.

## Features

### Core Systems

| System | Description |
|--------|-------------|
| **Life Score** | Daily score combining sleep, activity, work-life balance, and habits |
| **Timeline** | Smart daily schedule with time anchors and flexible routines |
| **RPG Stats** | Character progression with STR, INT, WIS, STA, CHA, LCK |
| **Skill Tree** | Path of Exile-inspired skill tree for personal growth |
| **Streaks** | Track consecutive completions with freeze tokens |
| **Achievements** | Unlock achievements for milestones and consistency |

### Integrations

| Service | Status | Purpose |
|---------|--------|---------|
| Oura Ring | Active | Sleep, activity, readiness scores |
| TimescaleDB | Active | Time-series health data |
| MQTT | Active | Real-time event bus |
| Home Assistant | Planned | Smart home control |
| Calendar | Planned | Schedule sync |

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    LifeOps Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐       ┌──────────────────┐            │
│  │   lifeops-api    │──────▶│   stats-api      │            │
│  │   Port: 8000     │       │   Port: 8001     │            │
│  │   Main API       │       │   RPG Stats      │            │
│  └────────┬─────────┘       └────────┬─────────┘            │
│           │                          │                       │
│           ▼                          ▼                       │
│  ┌──────────────────┐       ┌──────────────────┐            │
│  │   TimescaleDB    │       │   PostgreSQL     │            │
│  │   Port: 5432     │       │   Port: 5433     │            │
│  │   Health Data    │       │   Character Data │            │
│  └──────────────────┘       └──────────────────┘            │
│                                                              │
│  ┌──────────────────┐                                       │
│  │    Mosquitto     │                                       │
│  │    Port: 1883    │                                       │
│  │    Event Bus     │                                       │
│  └──────────────────┘                                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.12+ (for local development)
- Git

### Using Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/stephanbirkeland/LifeOps.git
cd LifeOps

# Copy environment template
cp .env.example .env
# Edit .env with your configuration

# Start all services
docker compose up -d

# Verify services are running
curl http://localhost:8000/health
curl http://localhost:8001/health
```

### Local Development

```bash
# Create virtual environment (Python 3.12 recommended)
python3.12 -m venv .venv
source .venv/bin/activate

# Install dependencies
cd services/api
pip install -r requirements-dev.txt

# Run tests
pytest tests/ -v

# Start API locally
uvicorn app.main:app --reload --port 8000
```

## API Documentation

Once running, access the interactive API documentation:

- **LifeOps API**: http://localhost:8000/docs
- **Stats API**: http://localhost:8001/docs

### Key Endpoints

```bash
# Get today's life score and status
GET /gamification/today

# Sync Oura data
POST /oura/sync

# Complete a timeline item
POST /timeline/{item_code}/complete

# Get character stats
GET /characters/{character_id}/stats

# Allocate skill tree points
POST /tree/allocate
```

## Project Structure

```
LifeOps/
├── services/
│   ├── api/                 # Main LifeOps API
│   │   ├── app/
│   │   │   ├── core/        # Config, database
│   │   │   ├── models/      # SQLAlchemy + Pydantic
│   │   │   ├── services/    # Business logic
│   │   │   └── routers/     # API endpoints
│   │   └── tests/           # pytest test suite
│   └── stats/               # Stats Service (RPG system)
│       ├── app/
│       │   ├── models/      # Character, skills, tree
│       │   ├── services/    # Progression, tree engine
│       │   └── routers/     # Stats endpoints
│       └── tests/
├── .claude/commands/        # AI agent definitions
├── docs/                    # Additional documentation
├── docker-compose.yml       # Container orchestration
└── *.md                     # Project documentation
```

## Documentation

| Document | Description |
|----------|-------------|
| [VISION.md](VISION.md) | Core philosophy and goals |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical architecture |
| [QUICKSTART.md](QUICKSTART.md) | Getting started guide |
| [CI_CD.md](CI_CD.md) | CI/CD pipeline and quality gates |
| [ROUTINES.md](ROUTINES.md) | Daily patterns and habits |
| [AGENTS.md](AGENTS.md) | Life domain agent definitions |
| [ROADMAP_TO_PRODUCTION.md](ROADMAP_TO_PRODUCTION.md) | Production timeline |

## Development

### Running Tests

```bash
# Run all tests
pytest tests/ -v

# Run with coverage
pytest tests/ --cov=app --cov-report=html

# Run specific test file
pytest tests/unit/test_gamification_model.py -v
```

### Code Quality

The project enforces strict quality gates with a minimum 60% test coverage requirement.

```bash
# Install pre-commit hooks
pip install pre-commit
pre-commit install

# Format code
ruff format services/api/app/ services/stats/app/

# Lint code
ruff check services/api/app/ services/stats/app/

# Type checking
mypy services/api/app/ --config-file=pyproject.toml
mypy services/stats/app/ --config-file=pyproject.toml
```

See [CI_CD.md](CI_CD.md) for detailed information on quality gates, pre-commit hooks, and pipeline configuration.

### AI-Assisted Development

This project uses Claude Code with 20 specialist agents for architecture, implementation, and review. See `.claude/commands/` for available agents:

```bash
# Architecture
/architect      # Chief architect coordination
/backend        # Infrastructure and APIs
/frontend       # Cross-platform UI

# Implementation
/fastapi-expert       # FastAPI patterns
/database-architect   # PostgreSQL/TimescaleDB
/testing-engineer     # pytest and coverage
/devops-specialist    # Docker and deployment

# Domain experts
/rpg-systems          # Gamification balance
/timeline-architect   # Scheduling logic
/health-data-specialist # Oura integration
```

## Tech Stack

- **Backend**: Python 3.12+, FastAPI, SQLAlchemy 2.0 (async)
- **Databases**: PostgreSQL 16, TimescaleDB
- **Message Broker**: Mosquitto (MQTT)
- **Containerization**: Docker, Docker Compose
- **Testing**: pytest, pytest-asyncio, httpx
- **Code Quality**: ruff, mypy

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed for **personal, non-commercial use only**. See the [LICENSE](LICENSE) file for details.

Commercial use, monetization, and derivative commercial works are prohibited without explicit permission.

## Acknowledgments

- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [TimescaleDB](https://www.timescale.com/) - Time-series database
- [Oura](https://ouraring.com/) - Health tracking integration
- [Path of Exile](https://www.pathofexile.com/) - Skill tree inspiration

---

**LifeOps** - Take control of your life, one day at a time.
