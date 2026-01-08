# Testing Setup Guide

## Python Version Compatibility Issue

**Current Issue**: Python 3.13 has compatibility issues with pydantic-core 2.16.2 during wheel building.

### Recommended Solutions

1. **Use Python 3.12** (Recommended)
   ```bash
   brew install python@3.12
   cd services/api
   python3.12 -m venv venv
   source venv/bin/activate
   pip install -r requirements-dev.txt -r requirements.txt
   ```

2. **Use Docker** (Alternative)
   ```bash
   docker-compose run --rm lifeops-api pytest tests/unit/ -v
   ```

3. **Use pre-built wheels** (Temporary workaround)
   ```bash
   pip install --only-binary=:all: pydantic pydantic-core asyncpg psycopg2-binary
   pip install -r requirements-dev.txt -r requirements.txt
   ```

## Running Tests

Once environment is set up:

```bash
# All tests
pytest

# Unit tests only
pytest tests/unit/ -v

# Integration tests only
pytest tests/integration/ -v

# With coverage
pytest --cov=app --cov-report=html tests/
```

## Test Structure

```
tests/
├── conftest.py           # Shared fixtures
├── unit/                 # Unit tests (no external dependencies)
│   ├── test_user_model.py
│   ├── test_health_model.py
│   ├── test_gamification_model.py
│   └── test_timeline_model.py
└── integration/          # Integration tests (with DB, APIs)
    ├── test_api_endpoints.py
    └── test_oura_sync.py
```

## Current Test Coverage

### Completed Unit Tests
- [x] User model (UserProfile, UserProfileUpdate, UserGoals)
- [x] Health model (HealthMetric, DailySummary, Oura data structures)
- [x] Gamification model (Streak, Achievement, DailyScore, XPInfo, TodayResponse)
- [x] Timeline model (TimelineItem, TimelineFeed, PostponeRequest, CompleteResponse)

### Pending Tests
- [ ] Oura service tests (with mocked API)
- [ ] Gamification service tests
- [ ] Timeline service tests
- [ ] API endpoint integration tests
- [ ] Database operation tests

## Known Issues

1. **Python 3.13**: pydantic-core build fails - use Python 3.12
2. **Database tests**: Need test database setup (see conftest.py)
3. **Async tests**: Require pytest-asyncio plugin

## Next Steps

1. Set up Python 3.12 virtual environment
2. Install all dependencies successfully
3. Run model tests to verify they pass
4. Write service layer tests
5. Write integration tests
6. Achieve 60% test coverage goal
