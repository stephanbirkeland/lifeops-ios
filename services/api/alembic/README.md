# Database Migrations with Alembic

This directory contains Alembic database migrations for the LifeOps API.

## Prerequisites

Ensure you have the dependencies installed:
```bash
pip install -r requirements.txt
```

## Configuration

The migration configuration is in `alembic.ini`. The database URL is automatically read from your environment variables via `app.core.config.settings`.

## Common Commands

### Create a New Migration

**Auto-generate from model changes:**
```bash
alembic revision --autogenerate -m "Add new table or column"
```

**Create empty migration:**
```bash
alembic revision -m "Custom migration description"
```

### Apply Migrations

**Upgrade to latest:**
```bash
alembic upgrade head
```

**Upgrade by one version:**
```bash
alembic upgrade +1
```

**Upgrade to specific revision:**
```bash
alembic upgrade <revision_id>
```

### Downgrade Migrations

**Downgrade by one version:**
```bash
alembic downgrade -1
```

**Downgrade to specific revision:**
```bash
alembic downgrade <revision_id>
```

**Downgrade all:**
```bash
alembic downgrade base
```

### View Migration History

**Current version:**
```bash
alembic current
```

**Show all revisions:**
```bash
alembic history
```

**Show verbose history:**
```bash
alembic history --verbose
```

## Migration Workflow

### 1. Make Model Changes

Edit your SQLAlchemy models in `app/models/`.

### 2. Generate Migration

```bash
# Let Alembic detect changes
alembic revision --autogenerate -m "Description of changes"
```

### 3. Review Generated Migration

**IMPORTANT**: Always review the generated migration file in `alembic/versions/` before applying it!

Alembic can miss certain changes:
- Table or column renames (appears as drop + create)
- Changes to column constraints
- Some index modifications

Edit the migration file to handle these correctly.

### 4. Test Migration

```bash
# Apply migration
alembic upgrade head

# Test that it works
# Run your tests or manually verify

# If issues, downgrade and fix
alembic downgrade -1
```

### 5. Commit Migration

Once tested, commit both the model changes and migration file:
```bash
git add app/models/ alembic/versions/
git commit -m "Add migration: <description>"
```

## Migration Best Practices

### DO:
- ✓ Always review auto-generated migrations
- ✓ Test migrations on a copy of production data
- ✓ Make migrations reversible when possible
- ✓ Keep migrations small and focused
- ✓ Add comments for complex migrations
- ✓ Test both upgrade and downgrade

### DON'T:
- ✗ Never edit existing migrations that have been deployed
- ✗ Don't create destructive migrations without backups
- ✗ Don't skip testing migrations
- ✗ Don't commit untested migrations

## Initial Setup (First Time)

### Create Initial Migration

If starting fresh with all models defined:

```bash
# Generate initial migration from current models
alembic revision --autogenerate -m "Initial database schema"

# Review the generated migration
# Then apply it
alembic upgrade head
```

### Stamp Existing Database

If you already have a database with tables:

```bash
# First, create an empty initial migration
alembic revision -m "Initial schema (existing database)"

# Edit the migration file to be empty (just pass in upgrade/downgrade)

# Stamp the database as being at this revision
alembic stamp head
```

## Troubleshooting

### "Can't locate revision"
- Check that you're in the correct directory
- Ensure alembic.ini points to the right versions directory

### "Target database is not up to date"
- Run `alembic current` to see current state
- Run `alembic upgrade head` to update

### Auto-generate not detecting changes
- Ensure models are imported in `alembic/env.py`
- Check that Base.metadata includes all models
- Some changes need manual migration creation

### Migration fails mid-way
```bash
# Check current state
alembic current

# If stuck, manually fix database and stamp
alembic stamp <revision_id>

# Or downgrade and fix migration
alembic downgrade -1
```

## Environment-Specific Migrations

### Development
```bash
export DATABASE_URL="postgresql+asyncpg://lifeops:dev@localhost:5432/lifeops_dev"
alembic upgrade head
```

### Testing
```bash
export DATABASE_URL="postgresql+asyncpg://lifeops:test@localhost:5432/lifeops_test"
alembic upgrade head
```

### Production
```bash
# Always backup first!
pg_dump lifeops > backup_$(date +%Y%m%d).sql

# Then migrate
alembic upgrade head
```

## Migration File Naming

Files are automatically named with timestamp and description:
```
20260108_1430_add_user_profile_table.py
```

This ensures chronological ordering and clear identification.

## References

- [Alembic Documentation](https://alembic.sqlalchemy.org/)
- [Alembic Tutorial](https://alembic.sqlalchemy.org/en/latest/tutorial.html)
- [Auto-generate Documentation](https://alembic.sqlalchemy.org/en/latest/autogenerate.html)
