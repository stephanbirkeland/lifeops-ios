# Contributing to LifeOps

Thank you for your interest in contributing to LifeOps! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/stephanbirkeland/LifeOps/issues)
2. If not, create a new issue using the bug report template
3. Include:
   - Clear description of the bug
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details (OS, Python version, Docker version)

### Suggesting Features

1. Check existing issues and discussions for similar suggestions
2. Create a new issue using the feature request template
3. Explain the use case and why this feature would be valuable

### Pull Requests

1. Fork the repository
2. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. Make your changes following our coding standards
4. Write or update tests as needed
5. Ensure all tests pass:
   ```bash
   pytest tests/ -v
   ```
6. Commit with a descriptive message:
   ```bash
   git commit -m "feat: add amazing new feature"
   ```
7. Push to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```
8. Open a Pull Request against `main`

## Development Setup

### Prerequisites

- Python 3.11+ (3.12 recommended)
- Docker and Docker Compose
- Git

### Local Environment

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/LifeOps.git
cd LifeOps

# Create virtual environment
python3.12 -m venv .venv
source .venv/bin/activate

# Install development dependencies
cd services/api
pip install -r requirements-dev.txt

# Run tests
pytest tests/ -v
```

### Using Docker

```bash
# Start all services
docker compose up -d

# Run tests in container
docker compose exec lifeops-api pytest tests/ -v

# View logs
docker compose logs -f
```

## Coding Standards

### Python Style

- Follow PEP 8 guidelines
- Use type hints for all function signatures
- Maximum line length: 100 characters
- Use `ruff` for formatting and linting

```bash
# Format code
ruff format app/

# Check for issues
ruff check app/

# Type checking
mypy app/
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `user_service.py` |
| Classes | PascalCase | `UserService` |
| Functions | snake_case | `get_user_by_id` |
| Constants | UPPER_SNAKE | `MAX_RETRIES` |
| SQLAlchemy Models | PascalCase + DB | `UserDB` |
| Pydantic Models | PascalCase | `UserCreate`, `UserResponse` |

### Project Structure

```
services/api/app/
├── core/           # Configuration, database setup
├── models/         # SQLAlchemy + Pydantic models
├── services/       # Business logic
├── routers/        # API endpoints
└── tests/          # Test suite
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code restructuring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(timeline): add streak recovery tokens
fix(oura): handle rate limiting gracefully
docs: update API documentation
test(gamification): add XP calculation tests
```

## Testing Guidelines

### Test Structure

```
tests/
├── conftest.py           # Shared fixtures
├── factories.py          # Test data factories
├── unit/                 # Unit tests
│   ├── test_models.py
│   └── test_services.py
├── integration/          # Integration tests
│   └── test_api.py
└── e2e/                  # End-to-end tests
```

### Writing Tests

```python
import pytest
from app.services.gamification import GamificationService

class TestGamificationService:
    """Tests for GamificationService"""

    def test_calculate_life_score_with_perfect_data(self):
        """Perfect scores should result in 100 life score"""
        service = GamificationService()
        score = service.calculate_life_score(
            sleep_score=100,
            activity_score=100,
            worklife_score=100,
            habits_score=100
        )
        assert score == 100.0

    def test_calculate_life_score_handles_none(self):
        """Should handle None values gracefully"""
        service = GamificationService()
        score = service.calculate_life_score(
            sleep_score=None,
            activity_score=80,
            worklife_score=70,
            habits_score=60
        )
        assert 0 <= score <= 100
```

### Test Coverage

- Aim for 80%+ coverage on services
- All new features must include tests
- Bug fixes should include regression tests

```bash
# Run with coverage
pytest tests/ --cov=app --cov-report=html

# View report
open htmlcov/index.html
```

## AI-Assisted Development

This project uses Claude Code with specialist agents. When contributing:

1. Review relevant agent definitions in `.claude/commands/`
2. Follow patterns established by agents (FastAPI, database, etc.)
3. Consider which agent would review your code

Available agents:
- `/fastapi-expert` - API patterns and best practices
- `/database-architect` - Schema design
- `/python-reviewer` - Code quality review
- `/testing-engineer` - Test patterns

## Documentation

- Update relevant `.md` files when changing features
- Add docstrings to new functions and classes
- Update API documentation if endpoints change
- Keep README.md current

## Questions?

- Open a [Discussion](https://github.com/stephanbirkeland/LifeOps/discussions) for questions
- Check existing documentation in the repository
- Review the agent definitions for architectural guidance

## License

By contributing, you agree that your contributions will be licensed under the same non-commercial license as the project. See [LICENSE](LICENSE) for details.

**Note**: This project prohibits commercial use and monetization.

---

Thank you for contributing to LifeOps!
