#!/usr/bin/env bash
#
# LifeOps Database Backup Script
#
# Backs up both TimescaleDB (lifeops) and Stats PostgreSQL databases
# with timestamped filenames.
#
# Usage:
#   ./backup.sh                    # Backup to default location
#   ./backup.sh /path/to/backups   # Backup to custom location
#
# Environment variables (optional):
#   LIFEOPS_DB_HOST     - TimescaleDB host (default: localhost)
#   LIFEOPS_DB_PORT     - TimescaleDB port (default: 5432)
#   LIFEOPS_DB_USER     - TimescaleDB user (default: lifeops)
#   LIFEOPS_DB_NAME     - TimescaleDB database name (default: lifeops)
#   STATS_DB_HOST       - Stats DB host (default: localhost)
#   STATS_DB_PORT       - Stats DB port (default: 5433)
#   STATS_DB_USER       - Stats DB user (default: stats)
#   STATS_DB_NAME       - Stats DB database name (default: stats)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration with defaults
LIFEOPS_DB_HOST="${LIFEOPS_DB_HOST:-localhost}"
LIFEOPS_DB_PORT="${LIFEOPS_DB_PORT:-5432}"
LIFEOPS_DB_USER="${LIFEOPS_DB_USER:-lifeops}"
LIFEOPS_DB_NAME="${LIFEOPS_DB_NAME:-lifeops}"

STATS_DB_HOST="${STATS_DB_HOST:-localhost}"
STATS_DB_PORT="${STATS_DB_PORT:-5433}"
STATS_DB_USER="${STATS_DB_USER:-stats}"
STATS_DB_NAME="${STATS_DB_NAME:-stats}"

# Backup directory (default: ./backups in script directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${1:-${SCRIPT_DIR}/../backups}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Create backup directory if it doesn't exist
mkdir -p "${BACKUP_DIR}"

log_info "Starting LifeOps database backup..."
log_info "Timestamp: ${TIMESTAMP}"
log_info "Backup directory: ${BACKUP_DIR}"

# Backup TimescaleDB (lifeops)
LIFEOPS_BACKUP="${BACKUP_DIR}/lifeops_${TIMESTAMP}.sql.gz"
log_info "Backing up TimescaleDB (lifeops) to ${LIFEOPS_BACKUP}..."

if pg_dump \
    -h "${LIFEOPS_DB_HOST}" \
    -p "${LIFEOPS_DB_PORT}" \
    -U "${LIFEOPS_DB_USER}" \
    -d "${LIFEOPS_DB_NAME}" \
    --no-password \
    --verbose \
    2>/dev/null | gzip > "${LIFEOPS_BACKUP}"; then
    LIFEOPS_SIZE=$(du -h "${LIFEOPS_BACKUP}" | cut -f1)
    log_info "TimescaleDB backup complete (${LIFEOPS_SIZE})"
else
    log_error "TimescaleDB backup failed!"
    # Continue with stats backup even if lifeops fails
fi

# Backup Stats PostgreSQL
STATS_BACKUP="${BACKUP_DIR}/stats_${TIMESTAMP}.sql.gz"
log_info "Backing up Stats DB to ${STATS_BACKUP}..."

if pg_dump \
    -h "${STATS_DB_HOST}" \
    -p "${STATS_DB_PORT}" \
    -U "${STATS_DB_USER}" \
    -d "${STATS_DB_NAME}" \
    --no-password \
    --verbose \
    2>/dev/null | gzip > "${STATS_BACKUP}"; then
    STATS_SIZE=$(du -h "${STATS_BACKUP}" | cut -f1)
    log_info "Stats DB backup complete (${STATS_SIZE})"
else
    log_error "Stats DB backup failed!"
fi

# Create a manifest file
MANIFEST="${BACKUP_DIR}/backup_${TIMESTAMP}.manifest"
cat > "${MANIFEST}" << EOF
LifeOps Backup Manifest
========================
Timestamp: ${TIMESTAMP}
Date: $(date -Iseconds)

Databases:
- lifeops (TimescaleDB): ${LIFEOPS_BACKUP}
- stats (PostgreSQL): ${STATS_BACKUP}

Configuration:
- LIFEOPS_DB_HOST: ${LIFEOPS_DB_HOST}
- LIFEOPS_DB_PORT: ${LIFEOPS_DB_PORT}
- STATS_DB_HOST: ${STATS_DB_HOST}
- STATS_DB_PORT: ${STATS_DB_PORT}
EOF

log_info "Backup manifest created: ${MANIFEST}"

# List recent backups
log_info "Recent backups in ${BACKUP_DIR}:"
ls -lht "${BACKUP_DIR}"/*.sql.gz 2>/dev/null | head -10 || log_warn "No backup files found"

# Cleanup old backups (keep last 7 days by default)
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"
OLD_BACKUPS=$(find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${RETENTION_DAYS} 2>/dev/null | wc -l)
if [ "${OLD_BACKUPS}" -gt 0 ]; then
    log_info "Cleaning up ${OLD_BACKUPS} backup(s) older than ${RETENTION_DAYS} days..."
    find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +${RETENTION_DAYS} -delete
    find "${BACKUP_DIR}" -name "*.manifest" -mtime +${RETENTION_DAYS} -delete
fi

log_info "Backup complete!"
