#!/bin/bash

# CI Configuration Validation Script
# Verifies that the CI/CD pipeline configuration is correct and complete

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== LifeOps CI/CD Configuration Validation ==="
echo ""
echo "Project root: $PROJECT_ROOT"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check functions
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} Found: $1"
        return 0
    else
        echo -e "${RED}✗${NC} Missing: $1"
        return 1
    fi
}

check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $3"
        return 0
    else
        echo -e "${RED}✗${NC} $3"
        return 1
    fi
}

ERRORS=0

# Check required files
echo "1. Checking required files..."
check_file "$PROJECT_ROOT/.github/workflows/ci.yml" || ERRORS=$((ERRORS+1))
check_file "$PROJECT_ROOT/pyproject.toml" || ERRORS=$((ERRORS+1))
check_file "$PROJECT_ROOT/services/api/requirements.txt" || ERRORS=$((ERRORS+1))
check_file "$PROJECT_ROOT/services/api/requirements-dev.txt" || ERRORS=$((ERRORS+1))
check_file "$PROJECT_ROOT/services/stats/requirements.txt" || ERRORS=$((ERRORS+1))
check_file "$PROJECT_ROOT/services/stats/requirements-dev.txt" || ERRORS=$((ERRORS+1))
echo ""

# Check Python version configuration
echo "2. Checking Python 3.12 configuration..."
check_content "$PROJECT_ROOT/pyproject.toml" "requires-python = \">=3.12\"" "pyproject.toml requires Python 3.12+" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/pyproject.toml" "target-version = \"py312\"" "Ruff target version is py312" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/pyproject.toml" "python_version = \"3.12\"" "MyPy target version is 3.12" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "PYTHON_VERSION: \"3.12\"" "CI workflow uses Python 3.12" || ERRORS=$((ERRORS+1))
echo ""

# Check coverage configuration
echo "3. Checking coverage configuration..."
check_content "$PROJECT_ROOT/pyproject.toml" "fail_under = 60" "Coverage threshold is 60%" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "COVERAGE_THRESHOLD: 60" "CI coverage threshold is 60%" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "cov-fail-under" "pytest configured with coverage fail threshold" || ERRORS=$((ERRORS+1))
echo ""

# Check workflow structure
echo "4. Checking CI workflow structure..."
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "name: CI" "Workflow has correct name" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "lint:" "Lint job exists" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "test-api:" "API test job exists" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "test-stats:" "Stats test job exists" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "docker-build:" "Docker build job exists" || ERRORS=$((ERRORS+1))
echo ""

# Check linting configuration
echo "5. Checking linting configuration..."
check_content "$PROJECT_ROOT/pyproject.toml" "\[tool.ruff\]" "Ruff configuration exists" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/pyproject.toml" "\[tool.ruff.lint\]" "Ruff lint rules configured" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "ruff format --check" "Ruff format check in CI" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "ruff check" "Ruff lint check in CI" || ERRORS=$((ERRORS+1))
echo ""

# Check test dependencies
echo "6. Checking test dependencies..."
check_content "$PROJECT_ROOT/services/api/requirements-dev.txt" "pytest" "API has pytest" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/services/api/requirements-dev.txt" "pytest-cov" "API has pytest-cov" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/services/api/requirements-dev.txt" "pytest-asyncio" "API has pytest-asyncio" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/services/api/requirements-dev.txt" "ruff" "API has ruff" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/services/stats/requirements-dev.txt" "pytest" "Stats has pytest" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/services/stats/requirements-dev.txt" "pytest-cov" "Stats has pytest-cov" || ERRORS=$((ERRORS+1))
echo ""

# Check pytest configuration
echo "7. Checking pytest configuration..."
check_content "$PROJECT_ROOT/pyproject.toml" "\[tool.pytest.ini_options\]" "Pytest configuration exists" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/pyproject.toml" "asyncio_mode = \"auto\"" "Pytest asyncio mode configured" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/pyproject.toml" "testpaths" "Test paths configured" || ERRORS=$((ERRORS+1))
echo ""

# Check caching in CI
echo "8. Checking CI caching configuration..."
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "cache: 'pip'" "Pip caching enabled in lint job" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "actions/cache@v4" "Cache action used in test jobs" || ERRORS=$((ERRORS+1))
echo ""

# Check database services in CI
echo "9. Checking CI database services..."
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "timescale/timescaledb" "TimescaleDB service configured for API tests" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/.github/workflows/ci.yml" "postgres:16-alpine" "PostgreSQL service configured for stats tests" || ERRORS=$((ERRORS+1))
echo ""

# Check badges in README
echo "10. Checking README badges..."
check_content "$PROJECT_ROOT/README.md" "Python 3.12+" "README has Python 3.12+ badge" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/README.md" "CI.*badge.svg" "README has CI badge" || ERRORS=$((ERRORS+1))
check_content "$PROJECT_ROOT/README.md" "codecov" "README has codecov badge" || ERRORS=$((ERRORS+1))
echo ""

# Summary
echo "=== Validation Summary ==="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo ""
    echo "The CI/CD pipeline configuration is complete and correct."
    exit 0
else
    echo -e "${RED}✗ Found $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the errors above before proceeding."
    exit 1
fi
