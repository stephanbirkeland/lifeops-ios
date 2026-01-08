# CI/CD Pipeline Setup Summary

This document summarizes the GitHub Actions CI/CD pipeline configuration for the LifeOps project.

## Overview

The LifeOps project now has a comprehensive CI/CD pipeline configured with Python 3.12, strict quality gates, and automated testing across all services.

## What's Configured

### 1. GitHub Actions Workflows

#### CI Workflow (`.github/workflows/ci.yml`)

The CI workflow runs on:
- Push to `main` and `develop` branches
- Pull requests to `main` and `develop` branches
- Manual trigger via `workflow_dispatch`

**Pipeline Jobs:**

1. **Code Quality (`lint`)**
   - Ruff format check (enforced, will fail CI)
   - Ruff lint check (enforced, will fail CI)
   - MyPy type checking (informational, won't fail CI)
   - Uses Python 3.12

2. **Test LifeOps API (`test-api`)**
   - Runs pytest with coverage
   - Uses TimescaleDB service for integration tests
   - Coverage threshold: 60% (enforced)
   - Uploads coverage to Codecov
   - Archives test results

3. **Test Stats Service (`test-stats`)**
   - Runs pytest with coverage
   - Uses PostgreSQL 16 service for integration tests
   - Coverage threshold: 60% (currently informational)
   - Uploads coverage to Codecov
   - Archives test results

4. **Docker Build (`docker-build`)**
   - Builds both API and Stats service Docker images
   - Uses Docker buildx with GitHub Actions cache
   - Verifies containers build successfully

5. **CI Success (`ci-success`)**
   - Final gate that ensures all jobs passed
   - Provides summary in GitHub Actions UI

### 2. Project Configuration (`pyproject.toml`)

**Python Version:**
- Requires Python 3.12+
- Ruff target: py312
- MyPy target: 3.12
- Black target: py312

**Ruff Configuration:**
- Line length: 100
- Comprehensive rule sets enabled (E, W, F, I, N, UP, B, C4, DTZ, etc.)
- FastAPI-friendly (allows function calls in defaults for Depends)
- Test files have relaxed rules (allows assert, magic values)

**Pytest Configuration:**
- Test paths: `services/api/tests`, `services/stats/tests`
- Async mode: auto (for pytest-asyncio)
- Markers defined: unit, integration, slow, oura, stats, mqtt
- Verbose output with strict configuration

**Coverage Configuration:**
- Minimum coverage: 60%
- Branch coverage enabled
- Covers: `services/api/app`, `services/stats/app`
- Excludes: tests, pycache, alembic, venv
- Outputs: XML (for Codecov), HTML (for local review)

### 3. Quality Gates

All PRs and pushes must pass:

| Gate | Enforcement | Threshold |
|------|-------------|-----------|
| Ruff Format | Hard fail | All files must be formatted |
| Ruff Lint | Hard fail | No lint errors allowed |
| MyPy Type Check | Soft fail | Informational only |
| API Tests | Hard fail | All tests must pass |
| API Coverage | Hard fail | Minimum 60% |
| Stats Tests | Hard fail | All tests must pass |
| Stats Coverage | Soft fail | Targeting 60% |
| Docker Build | Hard fail | Both images must build |

### 4. Caching Strategy

**Pip Dependencies:**
- Lint job: Uses `setup-python` cache with cache-dependency-path
- Test jobs: Uses `actions/cache@v4` for `~/.cache/pip`
- Keys based on requirements file hashes
- Significantly speeds up CI runs

**Docker Build:**
- Uses GitHub Actions cache
- Cache type: gha (GitHub Actions cache)
- Mode: max (cache all layers)

### 5. Documentation Updates

- **README.md**: Updated Python version badge to 3.12+
- **CI_CD.md**: Updated all references from 3.11 to 3.12
- **CI_SETUP_SUMMARY.md**: This document

## Files Modified

### Updated Files
- `.github/workflows/ci.yml` - Changed Python version from 3.11 to 3.12
- `pyproject.toml` - Updated all Python version references to 3.12
- `README.md` - Updated badges and documentation
- `CI_CD.md` - Updated Python version references

### New Files
- `scripts/validate-ci.sh` - Validation script to verify CI configuration

## Validation

Run the validation script to ensure the CI configuration is correct:

```bash
./scripts/validate-ci.sh
```

This script checks:
- All required files exist
- Python 3.12 configuration is consistent
- Coverage thresholds are set correctly
- Workflow structure is complete
- Dependencies are properly configured
- README badges are up to date

## Running Tests Locally

### API Service

```bash
cd services/api

# Install dependencies
pip install -r requirements-dev.txt

# Run tests with coverage
pytest tests/ -v --cov=app --cov-report=html --cov-report=term-missing

# Check coverage threshold
coverage report --fail-under=60

# View HTML coverage report
open htmlcov/index.html
```

### Stats Service

```bash
cd services/stats

# Install dependencies
pip install -r requirements-dev.txt

# Run tests with coverage
pytest tests/ -v --cov=app --cov-report=html --cov-report=term-missing

# Check coverage threshold
coverage report --fail-under=60
```

## Code Quality Checks

### Format Code

```bash
# Check formatting (what CI does)
ruff format --check services/api/app/ services/stats/app/

# Auto-format code
ruff format services/api/app/ services/stats/app/
```

### Lint Code

```bash
# Check for lint errors (what CI does)
ruff check services/api/app/ services/stats/app/

# Auto-fix lint errors
ruff check --fix services/api/app/ services/stats/app/
```

### Type Checking

```bash
# Check types for API
mypy services/api/app/ --config-file=pyproject.toml

# Check types for Stats
mypy services/stats/app/ --config-file=pyproject.toml
```

## Badges in README

The README includes these status badges:

- **Python 3.12+**: Shows minimum Python version
- **FastAPI**: Shows FastAPI version
- **CI**: Shows GitHub Actions CI status
- **Codecov**: Shows test coverage percentage
- **Code style: ruff**: Links to Ruff linter
- **pre-commit**: Shows pre-commit hooks are enabled

## Environment Variables

The CI pipeline uses these environment variables:

| Variable | Value | Description |
|----------|-------|-------------|
| `PYTHON_VERSION` | `3.12` | Python version for all jobs |
| `COVERAGE_THRESHOLD` | `60` | Minimum test coverage percentage |
| `DATABASE_URL` | `postgresql+asyncpg://...` | API test database connection |
| `STATS_SERVICE_URL` | `http://localhost:8001` | Stats service URL for API tests |
| `ENVIRONMENT` | `testing` | Environment mode for tests |

## Database Services in CI

### API Tests
- **Image**: `timescale/timescaledb:latest-pg16`
- **Port**: 5432
- **User**: lifeops
- **Password**: lifeops_test
- **Database**: lifeops_test
- **Health check**: `pg_isready` with retries

### Stats Tests
- **Image**: `postgres:16-alpine`
- **Port**: 5433 (mapped from 5432)
- **User**: stats
- **Password**: stats_test
- **Database**: stats_test
- **Health check**: `pg_isready` with retries

## Codecov Integration

The pipeline uploads coverage reports to Codecov for both services:

- **API Service**: Flag `api`
- **Stats Service**: Flag `stats`
- **Failure mode**: Won't fail CI if Codecov is down
- **Upload condition**: Always runs, even if tests fail

## Next Steps

1. **Set up Codecov** (if not already done):
   - Sign in to [codecov.io](https://codecov.io/) with GitHub
   - Enable the LifeOps repository
   - Add `CODECOV_TOKEN` to GitHub Secrets (optional, public repos don't need it)

2. **Enable GitHub Actions** (if not already done):
   - Go to repository Settings > Actions > General
   - Ensure "Allow all actions and reusable workflows" is selected

3. **Set up Branch Protection**:
   - Go to Settings > Branches > Branch protection rules
   - Add rule for `main` branch:
     - Require status checks to pass before merging
     - Select: `Code Quality`, `Test LifeOps API`, `Test Stats Service`, `Docker Build`
     - Require branches to be up to date before merging

4. **Monitor First CI Run**:
   - Push these changes or create a PR
   - Watch the Actions tab for the CI run
   - Verify all jobs pass

5. **Address Any Coverage Gaps**:
   - If coverage is below 60%, add more tests
   - Focus on untested critical paths first
   - Use the HTML coverage report to identify gaps

## Troubleshooting

### CI Failing on Format Check

```bash
# Auto-format your code
ruff format services/api/app/ services/stats/app/
git add -u
git commit -m "Format code with ruff"
```

### CI Failing on Lint Check

```bash
# See what's wrong
ruff check services/api/app/ services/stats/app/

# Auto-fix what can be fixed
ruff check --fix services/api/app/ services/stats/app/

# Fix remaining issues manually
```

### Coverage Below Threshold

```bash
# Run tests with coverage report
pytest tests/ --cov=app --cov-report=html --cov-report=term-missing

# Open HTML report to see what's not covered
open htmlcov/index.html

# Write tests for uncovered code
```

### Database Connection Errors in CI

- Check that the service is using the correct DATABASE_URL
- Verify health checks are passing (check job logs)
- Ensure migrations are running if needed

## References

- **GitHub Actions Docs**: https://docs.github.com/en/actions
- **Ruff Linter**: https://docs.astral.sh/ruff/
- **pytest**: https://docs.pytest.org/
- **pytest-cov**: https://pytest-cov.readthedocs.io/
- **Codecov**: https://docs.codecov.com/

---

**Setup Date**: 2026-01-08
**Python Version**: 3.12+
**Coverage Threshold**: 60%
**Status**: Validated and Ready
