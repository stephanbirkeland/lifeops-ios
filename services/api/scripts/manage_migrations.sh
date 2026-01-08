#!/bin/bash
# Database migration management script for LifeOps API

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if alembic is available
check_alembic() {
    if ! python -c "import alembic" 2>/dev/null; then
        error "Alembic is not installed. Run: pip install -r requirements.txt"
        exit 1
    fi
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 <command> [options]

Commands:
    current             Show current migration version
    history             Show migration history
    create <message>    Create new migration (auto-detect changes)
    create-empty <msg>  Create empty migration for manual editing
    upgrade [target]    Upgrade to target revision (default: head)
    downgrade <target>  Downgrade to target revision
    stamp <revision>    Stamp database with specific revision
    check               Check if database is up to date

Examples:
    $0 current
    $0 create "Add user preferences table"
    $0 upgrade head
    $0 downgrade -1
    $0 check
EOF
    exit 1
}

# Main command handling
check_alembic

case "$1" in
    current)
        info "Checking current database version..."
        alembic current
        ;;

    history)
        info "Migration history:"
        alembic history --verbose
        ;;

    create)
        if [ -z "$2" ]; then
            error "Migration message is required"
            usage
        fi
        info "Creating new migration: $2"
        alembic revision --autogenerate -m "$2"
        warn "Please review the generated migration file before applying!"
        ;;

    create-empty)
        if [ -z "$2" ]; then
            error "Migration message is required"
            usage
        fi
        info "Creating empty migration: $2"
        alembic revision -m "$2"
        ;;

    upgrade)
        TARGET="${2:-head}"
        info "Upgrading database to: $TARGET"

        # Backup reminder for production
        if [ "$DATABASE_ENV" = "production" ]; then
            warn "PRODUCTION DATABASE - Ensure you have a backup before proceeding!"
            read -p "Continue? (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                info "Upgrade cancelled"
                exit 0
            fi
        fi

        alembic upgrade "$TARGET"
        info "Migration completed successfully"
        ;;

    downgrade)
        if [ -z "$2" ]; then
            error "Target revision is required"
            usage
        fi
        warn "Downgrading database to: $2"

        # Extra confirmation for downgrades
        read -p "Are you sure you want to downgrade? (yes/no): " confirm
        if [ "$confirm" != "yes" ]; then
            info "Downgrade cancelled"
            exit 0
        fi

        alembic downgrade "$2"
        info "Downgrade completed"
        ;;

    stamp)
        if [ -z "$2" ]; then
            error "Revision is required"
            usage
        fi
        info "Stamping database with revision: $2"
        alembic stamp "$2"
        ;;

    check)
        info "Checking if database is up to date..."
        CURRENT=$(alembic current | grep "^[a-f0-9]" | cut -d' ' -f1)
        HEAD=$(alembic heads | cut -d' ' -f1)

        if [ "$CURRENT" = "$HEAD" ]; then
            info "✓ Database is up to date (revision: $CURRENT)"
            exit 0
        else
            warn "✗ Database is NOT up to date"
            echo "  Current: $CURRENT"
            echo "  Latest:  $HEAD"
            echo ""
            echo "Run '$0 upgrade head' to update"
            exit 1
        fi
        ;;

    *)
        error "Unknown command: $1"
        usage
        ;;
esac
