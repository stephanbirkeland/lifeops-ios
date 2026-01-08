# CI/CD Pipeline Documentation

This document describes the Continuous Integration and Continuous Deployment (CI/CD) pipeline for the LifeOps project.

## Table of Contents

- [Overview](#overview)
- [Continuous Integration (CI)](#continuous-integration-ci)
- [Continuous Deployment (CD)](#continuous-deployment-cd)
- [Quality Gates](#quality-gates)
- [Local Development Setup](#local-development-setup)
- [Configuration Files](#configuration-files)
- [Troubleshooting](#troubleshooting)

## Overview

The LifeOps CI/CD pipeline ensures code quality, runs comprehensive tests, and automates deployment across multiple environments. The pipeline is built using GitHub Actions and enforces strict quality standards before code can be merged or deployed.

### Pipeline Architecture

```
┌─────────────┐
│  Push/PR    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────┐
│    CI Pipeline (ci.yml)             │
│  ┌──────────────────────────────┐  │
│  │  1. Code Quality             │  │
│  │     - Ruff Format Check      │  │
│  │     - Ruff Lint              │  │
│  │     - MyPy Type Check        │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  2. Test API Service         │  │
│  │     - Unit Tests             │  │
│  │     - Integration Tests      │  │
│  │     - Coverage Check (60%)   │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  3. Test Stats Service       │  │
│  │     - Unit Tests             │  │
│  │     - Integration Tests      │  │
│  │     - Coverage Check (60%)   │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  4. Docker Build             │  │
│  │     - Build API Image        │  │
│  │     - Build Stats Image      │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  5. CI Success Check         │  │
│  │     - Verify All Jobs Pass   │  │
│  │     - Generate Summary       │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│    CD Pipeline (cd.yml)             │
│  ┌──────────────────────────────┐  │
│  │  1. Build & Push Images      │  │
│  │     - Push to GHCR           │  │
│  │     - Tag with version       │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  2. Deploy                   │  │
│  │     - Development (main)     │  │
│  │     - Staging (manual)       │  │
│  │     - Production (tags)      │  │
│  └──────────────────────────────┘  │
│  ┌──────────────────────────────┐  │
│  │  3. Create Release           │  │
│  │     - Generate Changelog     │  │
│  │     - Create GitHub Release  │  │
│  └──────────────────────────────┘  │
└─────────────────────────────────────┘
```

## Continuous Integration (CI)

The CI pipeline runs on every push to `main` or `develop` branches and on all pull requests.

### Workflow File

`.github/workflows/ci.yml`

### Triggers

- Push to `main` or `develop` branches
- Pull requests to `main` or `develop` branches
- Manual trigger via `workflow_dispatch`

### Jobs

#### 1. Code Quality

**Purpose**: Ensures code meets formatting and linting standards.

**Steps**:
- Ruff format check (enforces consistent code style)
- Ruff lint (catches common errors and anti-patterns)
- MyPy type checking (validates type hints)

**Failure Criteria**:
- Any formatting violations
- Any linting errors
- Type checking warnings (non-blocking)

#### 2. Test API Service

**Purpose**: Validates the LifeOps API service with comprehensive tests.

**Database**: TimescaleDB (PostgreSQL with time-series extensions)

**Steps**:
- Set up Python 3.12+
- Install dependencies from `requirements-dev.txt`
- Run pytest with coverage reporting
- Verify coverage threshold (60% minimum)
- Upload coverage to Codecov
- Archive test results

**Environment Variables**:
```bash
DATABASE_URL=postgresql+asyncpg://lifeops:lifeops_test@localhost:5432/lifeops_test
STATS_SERVICE_URL=http://localhost:8001
ENVIRONMENT=testing
```

**Failure Criteria**:
- Any test failures
- Coverage below 60%

#### 3. Test Stats Service

**Purpose**: Validates the Stats service with comprehensive tests.

**Database**: PostgreSQL 16

**Steps**:
- Set up Python 3.12+
- Install dependencies from `requirements-dev.txt`
- Run pytest with coverage reporting
- Verify coverage threshold (60% minimum, currently soft-fail)
- Upload coverage to Codecov
- Archive test results

**Environment Variables**:
```bash
DATABASE_URL=postgresql+asyncpg://stats:stats_test@localhost:5433/stats_test
ENVIRONMENT=testing
```

**Failure Criteria**:
- Test failures (currently soft-fail until tests are complete)
- Coverage below 60% (currently soft-fail)

#### 4. Docker Build

**Purpose**: Ensures Docker images can be built successfully.

**Steps**:
- Set up Docker Buildx
- Build API service image
- Build Stats service image
- Use GitHub Actions cache for faster builds

**Failure Criteria**:
- Build failures for any service

#### 5. CI Success Check

**Purpose**: Provides a single status check for branch protection rules.

**Steps**:
- Verify all previous jobs succeeded
- Generate pipeline summary

## Continuous Deployment (CD)

The CD pipeline handles building, tagging, and deploying Docker images to various environments.

### Workflow File

`.github/workflows/cd.yml`

### Triggers

- Push to `main` branch → Deploy to Development
- Tags matching `v*.*.*` → Deploy to Production
- Manual trigger → Choose environment

### Jobs

#### 1. Build and Push Docker Images

**Purpose**: Build and push versioned Docker images to GitHub Container Registry.

**Images**:
- `ghcr.io/<org>/lifeops-api`
- `ghcr.io/<org>/lifeops-stats`

**Tags**:
- `latest` - Latest main branch build
- `main-<sha>` - Specific commit on main
- `v1.2.3` - Semantic version tags
- `v1.2` - Major.minor version
- `v1` - Major version

**Registry**: GitHub Container Registry (GHCR)

#### 2. Deploy to Development

**Trigger**: Automatic on push to `main`

**Environment**: `development`

**Status**: Placeholder (not yet implemented)

**TODO**: Implement deployment automation:
1. SSH into development server
2. Pull latest Docker images
3. Run database migrations
4. Restart services with docker-compose
5. Verify service health

#### 3. Deploy to Staging

**Trigger**: Manual workflow dispatch

**Environment**: `staging`

**Status**: Placeholder (not yet implemented)

#### 4. Deploy to Production

**Trigger**: Automatic on version tags (`v*.*.*`)

**Environment**: `production`

**Status**: Placeholder (not yet implemented)

**TODO**: Implement production deployment:
1. Create backup of current state
2. SSH into production server
3. Pull specific version images
4. Run migrations with rollback support
5. Blue-green or rolling deployment
6. Smoke tests and health checks
7. Monitor for errors
8. Rollback if issues detected

#### 5. Create GitHub Release

**Trigger**: Automatic on version tags

**Steps**:
- Generate changelog from git commits
- Create GitHub release with notes
- Attach Docker image pull commands
- Mark pre-releases (alpha, beta, rc)

## Quality Gates

All code must pass these quality gates before being merged or deployed:

### 1. Code Formatting
- **Tool**: Ruff
- **Standard**: Project's `.ruff.toml` configuration
- **Line Length**: 100 characters
- **Enforcement**: CI pipeline blocks merge if fails

### 2. Code Linting
- **Tool**: Ruff
- **Rules**: Extensive ruleset (pycodestyle, pyflakes, isort, etc.)
- **Enforcement**: CI pipeline blocks merge if fails

### 3. Type Checking
- **Tool**: MyPy
- **Standard**: Python 3.12+ type hints
- **Enforcement**: Currently advisory (warnings don't block merge)

### 4. Test Coverage
- **Tool**: pytest-cov
- **Minimum**: 60% overall coverage
- **Reporting**: Codecov integration
- **Enforcement**: CI pipeline blocks merge if below threshold

### 5. Test Success
- **Framework**: pytest
- **Requirements**: All tests must pass
- **Types**: Unit tests, integration tests
- **Enforcement**: CI pipeline blocks merge if any test fails

### 6. Docker Build
- **Requirement**: Images must build successfully
- **Enforcement**: CI pipeline blocks merge if build fails

## Local Development Setup

### Prerequisites

```bash
# Install Python 3.12+
python --version  # Should be 3.12 or higher

# Install pre-commit
pip install pre-commit
```

### Setting Up Pre-commit Hooks

Pre-commit hooks run the same quality checks locally before you commit:

```bash
# Install pre-commit hooks
pre-commit install

# Install commit message hook (optional)
pre-commit install --hook-type commit-msg

# Run hooks manually on all files
pre-commit run --all-files

# Run specific hook
pre-commit run ruff --all-files
```

### Running Tests Locally

#### API Service Tests

```bash
cd services/api

# Install dependencies
pip install -r requirements-dev.txt

# Start test database (from project root)
docker-compose up -d timescaledb

# Run all tests with coverage
pytest tests/ -v --cov=app --cov-report=term-missing

# Run specific test types
pytest tests/unit/ -v            # Unit tests only
pytest tests/integration/ -v     # Integration tests only

# Run with markers
pytest -m "unit" -v              # Only unit tests
pytest -m "not slow" -v          # Skip slow tests
```

#### Stats Service Tests

```bash
cd services/stats

# Install dependencies
pip install -r requirements-dev.txt

# Start test database (from project root)
docker-compose up -d stats-db

# Run all tests with coverage
pytest tests/ -v --cov=app --cov-report=term-missing

# Run specific test types
pytest -m "character" -v         # Character system tests
pytest -m "skills" -v            # Skill tree tests
```

### Manual Quality Checks

```bash
# Format code
ruff format services/api/app/ services/stats/app/

# Check formatting without making changes
ruff format --check services/api/app/ services/stats/app/

# Run linter
ruff check services/api/app/ services/stats/app/

# Fix auto-fixable issues
ruff check --fix services/api/app/ services/stats/app/

# Type check
mypy services/api/app/ --config-file=pyproject.toml
mypy services/stats/app/ --config-file=pyproject.toml

# Check coverage
cd services/api
pytest --cov=app --cov-report=html
# Open htmlcov/index.html in browser
```

### Building Docker Images Locally

```bash
# Build API service
docker build -t lifeops-api:local services/api/

# Build Stats service
docker build -t lifeops-stats:local services/stats/

# Build all services with docker-compose
docker-compose build
```

## Configuration Files

### Core Configuration

| File | Purpose |
|------|---------|
| `pyproject.toml` | Central configuration for Ruff, MyPy, Pytest, Coverage |
| `.github/workflows/ci.yml` | CI pipeline definition |
| `.github/workflows/cd.yml` | CD pipeline definition |
| `.pre-commit-config.yaml` | Local pre-commit hooks |

### Service-Specific Configuration

| File | Purpose |
|------|---------|
| `services/api/pytest.ini` | API service test configuration |
| `services/api/requirements-dev.txt` | API development dependencies |
| `services/stats/pytest.ini` | Stats service test configuration |
| `services/stats/requirements-dev.txt` | Stats development dependencies |

### Tool Configuration Details

#### Ruff Configuration (`pyproject.toml`)

```toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "W", "F", "I", "N", "UP", "B", ...]
ignore = ["E501", "B008", "PLR0913", ...]
```

Key settings:
- 100 character line length
- Python 3.12 target
- Extensive rule selection
- FastAPI-specific exceptions

#### MyPy Configuration (`pyproject.toml`)

```toml
[tool.mypy]
python_version = "3.12"
warn_return_any = true
check_untyped_defs = true
strict_equality = true
```

Key settings:
- Python 3.12 type checking
- Warnings for common issues
- Ignore missing imports for libraries without stubs

#### Coverage Configuration (`pyproject.toml`)

```toml
[tool.coverage.run]
source = ["services/api/app", "services/stats/app"]
branch = true

[tool.coverage.report]
fail_under = 60
exclude_lines = ["pragma: no cover", ...]
```

Key settings:
- 60% minimum coverage
- Branch coverage enabled
- Exclude test files and boilerplate

## Troubleshooting

### CI Pipeline Failures

#### Formatting Check Fails

**Symptom**: Ruff format check fails

**Solution**:
```bash
# Fix formatting locally
ruff format services/api/app/ services/stats/app/

# Commit and push
git add .
git commit -m "Fix code formatting"
git push
```

#### Linting Errors

**Symptom**: Ruff lint check fails

**Solution**:
```bash
# Check what needs fixing
ruff check services/api/app/ services/stats/app/

# Auto-fix what's possible
ruff check --fix services/api/app/ services/stats/app/

# Manually fix remaining issues
# Commit and push
```

#### Coverage Below Threshold

**Symptom**: Coverage check fails with "Coverage below 60%"

**Solution**:
```bash
# Generate coverage report
cd services/api
pytest --cov=app --cov-report=html

# Open htmlcov/index.html to see uncovered lines
# Write tests for uncovered code
# Re-run tests to verify
pytest --cov=app --cov-fail-under=60
```

#### Test Failures

**Symptom**: Tests fail in CI but pass locally

**Common Causes**:
1. Database state differences
2. Environment variable issues
3. Race conditions in async tests
4. Time-dependent tests

**Solutions**:
```bash
# Clean database state
docker-compose down -v
docker-compose up -d

# Check environment variables match CI
cat services/api/pytest.ini  # Check [env] section

# Run tests with same settings as CI
cd services/api
pytest tests/ -v --cov=app --cov-fail-under=60
```

#### Docker Build Failures

**Symptom**: Docker build fails in CI

**Solution**:
```bash
# Build locally to reproduce
docker build -t lifeops-api:test services/api/

# Check Dockerfile and dependencies
# Fix issues and test again
# Commit and push
```

### Pre-commit Hook Issues

#### Hooks Fail to Run

**Symptom**: Pre-commit doesn't run on commit

**Solution**:
```bash
# Reinstall hooks
pre-commit uninstall
pre-commit install

# Update hooks to latest versions
pre-commit autoupdate

# Test hooks
pre-commit run --all-files
```

#### Hooks Take Too Long

**Symptom**: Pre-commit is slow

**Solution**:
```bash
# Skip hooks for a single commit (use sparingly)
git commit --no-verify -m "Your message"

# Or disable specific slow hooks in .pre-commit-config.yaml
# Comment out or remove hooks you don't need
```

### Deployment Issues

#### Images Not Found

**Symptom**: Deployment can't pull Docker images

**Solution**:
1. Check GHCR permissions
2. Verify image was built and pushed
3. Check image tag is correct
4. Authenticate with GHCR

```bash
# Login to GHCR
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# Pull image manually
docker pull ghcr.io/<org>/lifeops-api:latest
```

## Best Practices

### For Developers

1. **Run pre-commit hooks** - Let pre-commit catch issues before pushing
2. **Write tests first** - Maintain coverage above 60%
3. **Check CI status** - Don't merge until all checks pass
4. **Keep commits small** - Easier to debug CI failures
5. **Use descriptive commit messages** - Helps with changelog generation

### For Reviewers

1. **Check CI status** - Ensure all checks pass before approving
2. **Review test coverage** - Look at Codecov report in PR
3. **Verify quality gates** - All gates should be green
4. **Test locally if needed** - Pull PR branch and run tests
5. **Check deployment plan** - Understand deployment implications

### For Releases

1. **Use semantic versioning** - `v1.2.3` format
2. **Test in staging first** - Use manual workflow dispatch
3. **Review changelog** - Ensure release notes are accurate
4. **Monitor deployment** - Watch logs after deployment
5. **Have rollback plan** - Know how to revert if needed

## Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [pytest Documentation](https://docs.pytest.org/)
- [MyPy Documentation](https://mypy.readthedocs.io/)
- [pre-commit Documentation](https://pre-commit.com/)
- [Docker Documentation](https://docs.docker.com/)

## Support

For issues or questions about the CI/CD pipeline:

1. Check this documentation first
2. Review GitHub Actions logs for specific errors
3. Consult the troubleshooting section
4. Open an issue if you find a bug or need help
