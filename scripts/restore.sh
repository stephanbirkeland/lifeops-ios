#!/usr/bin/env bash
#
# LifeOps Database Restore Script
#
# Restores TimescaleDB (lifeops) and/or Stats PostgreSQL databases
# from backup files.
#
# Usage:
#   ./restore.sh lifeops_20240101_120000.sql.gz   # Restore lifeops DB
#   ./restore.sh stats_20240101_120000.sql.gz     # Restore stats DB
#   ./restore.sh --list                            # List available backups
#   ./restore.sh --latest                          # Restore latest backups for both DBs
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
BLUE='\033[0;34m'
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
BACKUP_DIR="${SCRIPT_DIR}/../backups"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_prompt() {
    echo -e "${BLUE}[PROMPT]${NC} $1"
}

usage() {
    echo "Usage: $0 <backup_file.sql.gz | --list | --latest>"
    echo ""
    echo "Options:"
    echo "  <file>      Path to backup file (lifeops_*.sql.gz or stats_*.sql.gz)"
    echo "  --list      List available backups"
    echo "  --latest    Restore latest backups for both databases"
    echo ""
    echo "Examples:"
    echo "  $0 backups/lifeops_20240101_120000.sql.gz"
    echo "  $0 --list"
    echo "  $0 --latest"
    exit 1
}

list_backups() {
    log_info "Available backups in ${BACKUP_DIR}:"
    echo ""

    if [ -d "${BACKUP_DIR}" ]; then
        echo "TimescaleDB (lifeops) backups:"
        ls -lht "${BACKUP_DIR}"/lifeops_*.sql.gz 2>/dev/null || echo "  No lifeops backups found"
        echo ""

        echo "Stats DB backups:"
        ls -lht "${BACKUP_DIR}"/stats_*.sql.gz 2>/dev/null || echo "  No stats backups found"
    else
        log_warn "Backup directory does not exist: ${BACKUP_DIR}"
    fi
}

restore_database() {
    local backup_file="$1"
    local db_type=""
    local db_host=""
    local db_port=""
    local db_user=""
    local db_name=""

    # Determine database type from filename
    if [[ "${backup_file}" == *"lifeops"* ]]; then
        db_type="lifeops"
        db_host="${LIFEOPS_DB_HOST}"
        db_port="${LIFEOPS_DB_PORT}"
        db_user="${LIFEOPS_DB_USER}"
        db_name="${LIFEOPS_DB_NAME}"
    elif [[ "${backup_file}" == *"stats"* ]]; then
        db_type="stats"
        db_host="${STATS_DB_HOST}"
        db_port="${STATS_DB_PORT}"
        db_user="${STATS_DB_USER}"
        db_name="${STATS_DB_NAME}"
    else
        log_error "Cannot determine database type from filename: ${backup_file}"
        log_error "Filename must contain 'lifeops' or 'stats'"
        return 1
    fi

    # Check if backup file exists
    if [ ! -f "${backup_file}" ]; then
        log_error "Backup file not found: ${backup_file}"
        return 1
    fi

    log_info "Restoring ${db_type} database from ${backup_file}..."
    log_info "Target: ${db_user}@${db_host}:${db_port}/${db_name}"

    # Confirm restoration
    log_prompt "This will REPLACE all data in ${db_name}. Continue? (yes/no)"
    read -r confirm

    if [ "${confirm}" != "yes" ]; then
        log_warn "Restore cancelled by user"
        return 0
    fi

    # Perform restore
    log_info "Decompressing and restoring..."

    if gunzip -c "${backup_file}" | psql \
        -h "${db_host}" \
        -p "${db_port}" \
        -U "${db_user}" \
        -d "${db_name}" \
        --no-password \
        --quiet \
        2>&1; then
        log_info "${db_type} database restored successfully!"
    else
        log_error "Failed to restore ${db_type} database!"
        return 1
    fi
}

restore_latest() {
    log_info "Looking for latest backups..."

    if [ ! -d "${BACKUP_DIR}" ]; then
        log_error "Backup directory does not exist: ${BACKUP_DIR}"
        exit 1
    fi

    # Find latest lifeops backup
    LATEST_LIFEOPS=$(ls -t "${BACKUP_DIR}"/lifeops_*.sql.gz 2>/dev/null | head -1 || true)
    if [ -n "${LATEST_LIFEOPS}" ]; then
        log_info "Latest lifeops backup: ${LATEST_LIFEOPS}"
    else
        log_warn "No lifeops backups found"
    fi

    # Find latest stats backup
    LATEST_STATS=$(ls -t "${BACKUP_DIR}"/stats_*.sql.gz 2>/dev/null | head -1 || true)
    if [ -n "${LATEST_STATS}" ]; then
        log_info "Latest stats backup: ${LATEST_STATS}"
    else
        log_warn "No stats backups found"
    fi

    if [ -z "${LATEST_LIFEOPS}" ] && [ -z "${LATEST_STATS}" ]; then
        log_error "No backups found to restore"
        exit 1
    fi

    log_prompt "Restore these backups? (yes/no)"
    read -r confirm

    if [ "${confirm}" != "yes" ]; then
        log_warn "Restore cancelled by user"
        exit 0
    fi

    # Restore each database
    if [ -n "${LATEST_LIFEOPS}" ]; then
        # Skip confirmation since we already confirmed
        log_info "Restoring lifeops from ${LATEST_LIFEOPS}..."
        if gunzip -c "${LATEST_LIFEOPS}" | psql \
            -h "${LIFEOPS_DB_HOST}" \
            -p "${LIFEOPS_DB_PORT}" \
            -U "${LIFEOPS_DB_USER}" \
            -d "${LIFEOPS_DB_NAME}" \
            --no-password \
            --quiet \
            2>&1; then
            log_info "lifeops database restored successfully!"
        else
            log_error "Failed to restore lifeops database!"
        fi
    fi

    if [ -n "${LATEST_STATS}" ]; then
        log_info "Restoring stats from ${LATEST_STATS}..."
        if gunzip -c "${LATEST_STATS}" | psql \
            -h "${STATS_DB_HOST}" \
            -p "${STATS_DB_PORT}" \
            -U "${STATS_DB_USER}" \
            -d "${STATS_DB_NAME}" \
            --no-password \
            --quiet \
            2>&1; then
            log_info "stats database restored successfully!"
        else
            log_error "Failed to restore stats database!"
        fi
    fi

    log_info "Restore complete!"
}

# Main
if [ $# -eq 0 ]; then
    usage
fi

case "$1" in
    --list)
        list_backups
        ;;
    --latest)
        restore_latest
        ;;
    --help|-h)
        usage
        ;;
    *)
        restore_database "$1"
        ;;
esac
