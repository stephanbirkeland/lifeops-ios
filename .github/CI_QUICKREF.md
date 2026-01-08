# CI/CD Quick Reference

Quick commands for working with the LifeOps CI/CD pipeline.

## Prerequisites

```bash
# Ensure you have Python 3.12+
python --version

# Install dependencies
cd services/api && pip install -r requirements-dev.txt
cd services/stats && pip install -r requirements-dev.txt
```

## Before Committing

Run these commands to ensure your code will pass CI:

```bash
# From project root

# 1. Format code
ruff format services/api/app/ services/stats/app/

# 2. Fix lint errors
ruff check --fix services/api/app/ services/stats/app/

# 3. Run tests
cd services/api && pytest tests/ -v
cd services/stats && pytest tests/ -v

# 4. Check coverage
cd services/api && pytest tests/ --cov=app --cov-report=term-missing
cd services/stats && pytest tests/ --cov=app --cov-report=term-missing
```

## One-Liner CI Simulation

```bash
# API Service
ruff format --check services/api/app/ && \
ruff check services/api/app/ && \
cd services/api && pytest tests/ --cov=app --cov-fail-under=60

# Stats Service
ruff format --check services/stats/app/ && \
ruff check services/stats/app/ && \
cd services/stats && pytest tests/ --cov=app --cov-fail-under=60
```

## Validate CI Configuration

```bash
./scripts/validate-ci.sh
```

## Common Commands

| Task | Command |
|------|---------|
| Format check | `ruff format --check <path>` |
| Format fix | `ruff format <path>` |
| Lint check | `ruff check <path>` |
| Lint fix | `ruff check --fix <path>` |
| Type check | `mypy <path> --config-file=pyproject.toml` |
| Run tests | `pytest tests/ -v` |
| Test with coverage | `pytest tests/ --cov=app --cov-report=html` |
| Check coverage | `coverage report --fail-under=60` |
| View coverage | `open htmlcov/index.html` |

## Test Markers

Run specific test categories:

```bash
pytest tests/ -m unit          # Unit tests only
pytest tests/ -m integration   # Integration tests only
pytest tests/ -m "not slow"    # Skip slow tests
pytest tests/ -m oura          # Oura API tests only
```

## Coverage Tips

```bash
# Show lines missing coverage
pytest tests/ --cov=app --cov-report=term-missing

# Generate HTML report
pytest tests/ --cov=app --cov-report=html

# Check specific module
pytest tests/ --cov=app.services.gamification --cov-report=term-missing
```

## CI Pipeline Status

Check CI status:
- GitHub Actions: https://github.com/stephanbirkeland/LifeOps/actions
- Badge in README: Shows current status

## Quality Gates

Must pass for PR merge:
- Ruff format check
- Ruff lint check
- All tests passing
- 60% test coverage (API)
- Docker builds successful

## Troubleshooting

**Format errors?**
```bash
ruff format services/api/app/ services/stats/app/
```

**Lint errors?**
```bash
ruff check --fix services/api/app/ services/stats/app/
# Fix remaining issues manually
```

**Coverage too low?**
```bash
pytest tests/ --cov=app --cov-report=html
open htmlcov/index.html
# Write tests for red/uncovered lines
```

**Tests failing locally but not in CI (or vice versa)?**
```bash
# Check environment variables
# Ensure database is running
docker compose up -d timescaledb stats-db
# Re-run tests
```

## Environment Variables

Set these for local testing:

```bash
export DATABASE_URL="postgresql+asyncpg://lifeops:lifeops_dev_password@localhost:5432/lifeops"
export STATS_SERVICE_URL="http://localhost:8001"
export ENVIRONMENT="testing"
```

## Docker Commands

```bash
# Build locally (what CI does)
docker build -t lifeops-api:test services/api
docker build -t stats-api:test services/stats

# Run full stack
docker compose up -d

# Run tests in container
docker compose exec lifeops-api pytest tests/ -v
docker compose exec stats-api pytest tests/ -v
```

## Pre-commit Hooks

Install pre-commit hooks to run checks automatically:

```bash
pip install pre-commit
pre-commit install

# Run on all files
pre-commit run --all-files
```

## Getting Help

- CI/CD full docs: [CI_CD.md](../CI_CD.md)
- Setup summary: [CI_SETUP_SUMMARY.md](../CI_SETUP_SUMMARY.md)
- Ruff docs: https://docs.astral.sh/ruff/
- pytest docs: https://docs.pytest.org/

---

Keep this file open when working on the project for quick reference!
