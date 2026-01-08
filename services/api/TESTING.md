# LifeOps API Testing Guide

## Quick Start

### Install Test Dependencies

```bash
cd /Users/stephanbirkeland/workspace/personal/LifeOps/services/api

# Install development dependencies
pip install -r requirements-dev.txt
```

### Run All Tests

```bash
# Run all tests with coverage
pytest

# Run only unit tests (fast)
pytest -m unit

# Run only integration tests
pytest -m integration

# Run specific test file
pytest tests/unit/test_health_endpoint.py

# Run with verbose output
pytest -v

# Run without coverage (faster)
pytest --no-cov
```

### Test Database Setup

The tests use a separate test database to avoid affecting your development data.

**Option 1: Use Docker (Recommended)**

```bash
# Start a test database
docker run -d \
  --name lifeops-test-db \
  -e POSTGRES_USER=lifeops \
  -e POSTGRES_PASSWORD=lifeops_test \
  -e POSTGRES_DB=lifeops_test \
  -p 5433:5432 \
  postgres:15

# Stop when done
docker stop lifeops-test-db
docker rm lifeops-test-db
```

**Option 2: Use Existing PostgreSQL**

```sql
-- Connect to PostgreSQL
psql -U postgres

-- Create test database and user
CREATE DATABASE lifeops_test;
CREATE USER lifeops WITH PASSWORD 'lifeops_test';
GRANT ALL PRIVILEGES ON DATABASE lifeops_test TO lifeops;
```

### Environment Variables

Tests use environment variables from `pytest.ini`. Override if needed:

```bash
# Custom test database
export TEST_DATABASE_URL="postgresql+asyncpg://user:pass@localhost:5432/test_db"

# Run tests
pytest
```

## Test Structure

```
tests/
├── conftest.py              # Shared fixtures and configuration
├── unit/                    # Unit tests (fast, isolated)
│   ├── test_health_endpoint.py
│   ├── test_models.py
│   └── test_services.py
├── integration/             # Integration tests (database, APIs)
│   ├── test_oura_integration.py
│   ├── test_timeline_api.py
│   └── test_gamification_flow.py
└── fixtures/                # Test data and helpers
    └── sample_data.py
```

## Test Markers

Tests are categorized with markers for selective execution:

```bash
# Run only fast unit tests
pytest -m unit

# Run integration tests (require database)
pytest -m integration

# Skip slow tests
pytest -m "not slow"

# Run Oura-related tests
pytest -m oura

# Run stats service tests
pytest -m stats
```

## Writing Tests

### Unit Test Example

```python
import pytest
from app.services.gamification import calculate_life_score


@pytest.mark.unit
def test_calculate_life_score_perfect():
    """Test Life Score with perfect domain scores."""
    domains = {
        "sleep": 100,
        "activity": 100,
        "worklife": 100,
        "habits": 100
    }
    score = calculate_life_score(domains)
    assert score == 100.0


@pytest.mark.unit
def test_calculate_life_score_weights():
    """Test that domain weights are applied correctly."""
    domains = {
        "sleep": 100,    # 40% weight
        "activity": 0,   # 25% weight
        "worklife": 0,   # 20% weight
        "habits": 0      # 15% weight
    }
    score = calculate_life_score(domains)
    assert score == 40.0  # Only sleep contributes
```

### Integration Test Example

```python
import pytest
from httpx import AsyncClient


@pytest.mark.integration
@pytest.mark.asyncio
async def test_create_and_retrieve_user(async_client: AsyncClient):
    """Test creating a user and retrieving their profile."""
    # Create user
    user_data = {
        "email": "test@example.com",
        "name": "Test User",
        "timezone": "Europe/Oslo"
    }
    response = await async_client.post("/user/register", json=user_data)
    assert response.status_code == 201
    user_id = response.json()["id"]

    # Retrieve user
    response = await async_client.get(f"/user/{user_id}")
    assert response.status_code == 200
    user = response.json()
    assert user["email"] == user_data["email"]
    assert user["name"] == user_data["name"]
```

### Using Fixtures

```python
@pytest.mark.unit
def test_oura_sync_with_mock(mock_oura_api, test_user_id):
    """Test Oura sync with mocked API."""
    # mock_oura_api and test_user_id are fixtures from conftest.py
    from app.services.oura import sync_sleep_data

    result = sync_sleep_data(test_user_id)
    assert result.success is True
    assert len(result.sleep_sessions) > 0
```

## Coverage Reports

### Generate Coverage Report

```bash
# Run tests with coverage
pytest

# Coverage report is generated in multiple formats:
# - Terminal output (immediately visible)
# - HTML report in htmlcov/index.html
# - JSON report in coverage.json
```

### View HTML Coverage Report

```bash
# After running tests, open HTML report
open htmlcov/index.html  # macOS
xdg-open htmlcov/index.html  # Linux
```

### Coverage Goals

- **Phase 1 Target**: 40% coverage
- **Phase 2 Target**: 60% coverage (minimum for production)
- **Long-term Target**: 80%+ coverage

Current coverage threshold is set to 60% in `pytest.ini`. Tests will fail if coverage drops below this.

## Continuous Integration

### Pre-commit Checks

Before committing code, run:

```bash
# Run all tests
pytest

# Run code formatters
black app/ tests/
ruff check app/ tests/ --fix

# Run type checker
mypy app/
```

### GitHub Actions (Future)

CI pipeline will run:
1. All tests on every commit
2. Code quality checks (black, ruff, mypy)
3. Coverage enforcement
4. Docker image build

## Debugging Tests

### Verbose Output

```bash
# Show print statements
pytest -s

# Show detailed test info
pytest -vv

# Show why tests were skipped
pytest -rs
```

### Debug Specific Test

```bash
# Run single test with debugger
pytest tests/unit/test_models.py::test_user_creation --pdb

# Or use VS Code debugger with this launch.json:
{
  "name": "Debug Pytest",
  "type": "python",
  "request": "launch",
  "module": "pytest",
  "args": ["tests/unit/test_models.py::test_user_creation", "-v"]
}
```

### Common Issues

**Issue**: `ImportError: cannot import name 'app'`
**Solution**: Make sure you're in the correct directory and PYTHONPATH is set:
```bash
cd /Users/stephanbirkeland/workspace/personal/LifeOps/services/api
export PYTHONPATH=$(pwd)
pytest
```

**Issue**: `Database connection failed`
**Solution**: Ensure test database is running and connection string is correct:
```bash
# Check if database is accessible
psql -h localhost -p 5433 -U lifeops -d lifeops_test
```

**Issue**: `Fixture 'db_session' not found`
**Solution**: Ensure `conftest.py` is present in `tests/` directory.

## Best Practices

### 1. Test Independence
- Each test should be independent
- Don't rely on test execution order
- Use fixtures for setup/teardown

### 2. Test Naming
- Use descriptive test names: `test_<what>_<condition>_<expected>`
- Example: `test_calculate_score_with_missing_data_returns_default`

### 3. Arrange-Act-Assert Pattern

```python
def test_example():
    # Arrange: Set up test data
    user = create_test_user()

    # Act: Execute the code under test
    result = user.calculate_score()

    # Assert: Verify the results
    assert result == expected_value
```

### 4. Use Parametrize for Multiple Cases

```python
@pytest.mark.parametrize("input,expected", [
    (100, "excellent"),
    (80, "good"),
    (60, "fair"),
    (40, "poor"),
])
def test_score_classification(input, expected):
    assert classify_score(input) == expected
```

### 5. Mock External Services
- Always mock Oura API in tests
- Mock Stats Service in LifeOps API tests
- Use `monkeypatch` or `pytest-mock`

## Performance

### Fast Test Suite
- Unit tests should complete in <1s
- Full suite should complete in <30s
- Use `@pytest.mark.slow` for tests >1s

### Parallel Execution (Future)

```bash
# Install pytest-xdist
pip install pytest-xdist

# Run tests in parallel
pytest -n auto
```

## Maintenance

### Update Test Dependencies

```bash
# Update to latest compatible versions
pip install -U -r requirements-dev.txt

# Or update specific package
pip install -U pytest
```

### Adding New Test Categories

Edit `pytest.ini` to add new markers:

```ini
markers =
    unit: Unit tests
    integration: Integration tests
    mycategory: Description of my new category
```

---

## Next Steps

1. **Write more tests**: Aim for 60% coverage
2. **Set up CI/CD**: Automate testing on every commit
3. **Add performance tests**: Verify API response times
4. **Add security tests**: SQL injection, XSS, etc.

For questions, see project documentation or ask the orchestrator.
