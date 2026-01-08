# LifeOps Backend Architecture

**Version:** 1.0
**Last Updated:** 2026-01-08
**Author:** Backend Architect Agent

This document defines the complete backend architecture for LifeOps, prioritizing privacy, efficiency, reliability, and multi-location capabilities.

---

## Executive Summary

**Hardware Choice:** Raspberry Pi 5 (8GB) as primary hub + fallback to Linux PCs
**Database:** SQLite + TimescaleDB (PostgreSQL extension)
**API:** REST + WebSocket hybrid
**Containerization:** Docker Compose with resource limits
**Sync Strategy:** Multi-master CRDTs with conflict-free replication

---

## 1. Central Hub Strategy

### Hardware Recommendation: Raspberry Pi 5 (8GB)

**Primary Hub Hardware:**
- **Raspberry Pi 5 (8GB RAM)** - Available and perfect for this use case
- MicroSD card (128GB, Application Class 2) + USB SSD (512GB) for database
- Official power supply (27W USB-C)
- Passive cooling case or low-profile fan

**Resource Profile:**
- **CPU:** Quad-core ARM Cortex-A76 @ 2.4GHz (efficient, sufficient)
- **RAM:** 8GB (comfortable for multiple containers)
- **Storage:** SSD for database I/O, SD card for OS
- **Power:** ~5-8W typical, ~15W max (extremely efficient)
- **Network:** Gigabit Ethernet + WiFi 6
- **Cost:** ~$100 total (Pi + case + power + storage)

**Why Raspberry Pi 5 over alternatives:**

| Factor | Raspberry Pi 5 | Mini PC | NAS |
|--------|----------------|---------|-----|
| Power consumption | 5-8W | 15-45W | 30-100W |
| Cost | $100 | $300-600 | $400-1000 |
| Noise | Silent | Fan noise | Fan noise |
| Availability | You have one | Need to buy | Need to buy |
| ARM compatibility | Excellent | x86 | x86 |
| Overkill factor | Perfect fit | Too much | Too much |

**Fallback Strategy:**
- Linux PCs at each location can run LifeOps stack
- Same Docker Compose setup works across Pi and x86
- Automatic failover if Pi goes down (see Sync Strategy)

### High Availability Approach

**Primary:** Pi at home (always-on)
**Secondaries:** Linux PCs at home and cabins (opportunistic)
**Principle:** Accept eventual consistency, prioritize availability

```
┌─────────────────────────────────────────────────────────┐
│                    LifeOps Deployment                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  HOME                 SUMMER CABIN      WINTER CABIN    │
│  ┌─────────┐         ┌─────────┐      ┌─────────┐     │
│  │ Pi 5    │◄────────│ Linux PC│◄─────│ Linux PC│     │
│  │ PRIMARY │  sync   │ REPLICA │ sync │ REPLICA │     │
│  └────┬────┘         └─────────┘      └─────────┘     │
│       │                                                 │
│  ┌────┴────┐                                            │
│  │Linux PC │                                            │
│  │ BACKUP  │                                            │
│  └─────────┘                                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 2. Database Architecture

### Hybrid Approach: SQLite + TimescaleDB

**Philosophy:** Different data types need different storage solutions.

### 2.1 SQLite (Application Database)

**Use Cases:**
- Configuration and settings
- User preferences
- Agent state and rules
- Device registry
- Event log (recent)
- Calendar cache
- Automation definitions

**Rationale:**
- **Zero configuration** - Single file, no server process
- **Extremely efficient** - Perfect for Pi's resource constraints
- **ACID compliant** - Reliable for critical config data
- **Embedded** - No network overhead
- **Backup-friendly** - Just copy the file
- **Tested** - Used by iOS, Android, browsers everywhere

**Configuration:**
```sql
-- WAL mode for concurrent reads during writes
PRAGMA journal_mode=WAL;

-- Optimize for safety on embedded device
PRAGMA synchronous=NORMAL;

-- Memory cache (tune for 8GB Pi)
PRAGMA cache_size=-64000; -- 64MB cache

-- Auto-vacuum to prevent fragmentation
PRAGMA auto_vacuum=INCREMENTAL;
```

**File Location:** `/data/lifeops/db/lifeops.db` (on SSD, not SD card)

### 2.2 TimescaleDB (Time-Series Database)

**Use Cases:**
- Oura Ring health metrics (sleep, HRV, activity, temperature)
- Screen time tracking
- Work hours logging
- Device state history
- Network activity
- Habit completion events
- XP and gamification history

**Rationale:**
- **Time-series optimized** - Compression, partitioning, fast range queries
- **PostgreSQL foundation** - Mature, reliable, well-documented
- **Efficient on Pi** - Tested and works well with proper configuration
- **Retention policies** - Automatic data aging and aggregation
- **Rich queries** - Full SQL for complex analytics

**Why not InfluxDB?**
- TimescaleDB is PostgreSQL (familiar, more integrations)
- Better compression on ARM
- Standard SQL (easier to work with)
- Resource usage more predictable

**Configuration for Raspberry Pi:**
```yaml
# docker-compose.yml - Timescale service
timescale:
  image: timescale/timescaledb:latest-pg16
  volumes:
    - /data/lifeops/tsdb:/var/lib/postgresql/data
  environment:
    POSTGRES_DB: lifeops_metrics
    POSTGRES_USER: lifeops
    POSTGRES_PASSWORD: ${TSDB_PASSWORD}
  shm_size: 256mb
  deploy:
    resources:
      limits:
        cpus: '2.0'
        memory: 2G
      reservations:
        memory: 512M
```

**PostgreSQL tuning for Pi:**
```ini
# postgresql.conf adjustments
shared_buffers = 512MB
effective_cache_size = 2GB
maintenance_work_mem = 128MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1  # SSD
effective_io_concurrency = 200  # SSD
work_mem = 4MB  # Low to prevent memory exhaustion
max_worker_processes = 4
max_parallel_workers_per_gather = 2
max_parallel_workers = 4
```

**Retention Strategy:**
```sql
-- Keep raw data for 90 days
SELECT add_retention_policy('health_metrics', INTERVAL '90 days');

-- Aggregate to hourly after 7 days
CREATE MATERIALIZED VIEW health_metrics_hourly
WITH (timescaledb.continuous) AS
SELECT time_bucket('1 hour', timestamp) AS hour,
       metric_type,
       AVG(value) as avg_value,
       MIN(value) as min_value,
       MAX(value) as max_value,
       COUNT(*) as sample_count
FROM health_metrics
GROUP BY hour, metric_type;

-- Keep aggregated data for 2 years
SELECT add_retention_policy('health_metrics_hourly', INTERVAL '2 years');
```

### 2.3 Schema Design

**SQLite Schema (Application DB):**

```sql
-- Core configuration
CREATE TABLE settings (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Device registry
CREATE TABLE devices (
    device_id TEXT PRIMARY KEY,
    device_name TEXT NOT NULL,
    device_type TEXT NOT NULL, -- 'phone', 'computer', 'speaker', 'light', etc.
    location TEXT, -- 'home', 'summer_cabin', 'winter_cabin', 'mobile'
    ecosystem TEXT, -- 'apple', 'google', 'samsung', 'linux', 'plejd', etc.
    capabilities TEXT, -- JSON array
    last_seen TIMESTAMP,
    metadata TEXT -- JSON for device-specific data
);

-- Agent state
CREATE TABLE agent_state (
    agent_id TEXT PRIMARY KEY,
    state TEXT NOT NULL, -- JSON state blob
    last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Calendar events (cached from sources)
CREATE TABLE calendar_events (
    event_id TEXT PRIMARY KEY,
    source TEXT NOT NULL, -- 'icloud', 'google', 'outlook'
    title TEXT NOT NULL,
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP NOT NULL,
    all_day BOOLEAN DEFAULT 0,
    location TEXT,
    description TEXT,
    metadata TEXT, -- JSON for additional fields
    synced_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_calendar_events_time ON calendar_events(start_time, end_time);

-- Automation rules
CREATE TABLE automation_rules (
    rule_id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    agent TEXT NOT NULL,
    trigger_type TEXT NOT NULL, -- 'time', 'event', 'condition'
    trigger_config TEXT NOT NULL, -- JSON
    action_config TEXT NOT NULL, -- JSON
    enabled BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notification queue
CREATE TABLE notification_queue (
    notification_id TEXT PRIMARY KEY,
    agent TEXT NOT NULL,
    priority INTEGER NOT NULL, -- 1=urgent, 2=important, 3=normal, 4=low
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    action_url TEXT,
    target_devices TEXT, -- JSON array of device_ids
    scheduled_for TIMESTAMP NOT NULL,
    delivered_at TIMESTAMP,
    status TEXT DEFAULT 'pending' -- 'pending', 'delivered', 'failed', 'dismissed'
);

CREATE INDEX idx_notification_queue_scheduled ON notification_queue(scheduled_for, status);

-- Sync metadata (for multi-location replication)
CREATE TABLE sync_metadata (
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    version INTEGER NOT NULL,
    node_id TEXT NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (table_name, record_id)
);
```

**TimescaleDB Schema (Metrics DB):**

```sql
-- Enable TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Health metrics from Oura Ring
CREATE TABLE health_metrics (
    timestamp TIMESTAMPTZ NOT NULL,
    metric_type TEXT NOT NULL, -- 'sleep_score', 'readiness', 'hrv', 'resting_hr', 'temperature_deviation', 'activity_score'
    value NUMERIC NOT NULL,
    metadata JSONB, -- Additional context like sleep stage, activity type
    source TEXT DEFAULT 'oura',
    PRIMARY KEY (timestamp, metric_type)
);

SELECT create_hypertable('health_metrics', 'timestamp');
CREATE INDEX idx_health_metrics_type ON health_metrics(metric_type, timestamp DESC);

-- Sleep sessions (detailed sleep data)
CREATE TABLE sleep_sessions (
    session_id TEXT PRIMARY KEY,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    total_sleep_duration INTEGER, -- minutes
    efficiency NUMERIC,
    deep_sleep INTEGER, -- minutes
    rem_sleep INTEGER, -- minutes
    light_sleep INTEGER, -- minutes
    awake INTEGER, -- minutes
    latency INTEGER, -- minutes to fall asleep
    hrv_average NUMERIC,
    resting_hr_average NUMERIC,
    temperature_deviation NUMERIC,
    score INTEGER,
    metadata JSONB
);

SELECT create_hypertable('sleep_sessions', 'start_time');

-- Activity tracking
CREATE TABLE activity_events (
    timestamp TIMESTAMPTZ NOT NULL,
    activity_type TEXT NOT NULL, -- 'workout', 'walk', 'steps', 'workout_complete'
    duration INTEGER, -- minutes
    intensity TEXT, -- 'low', 'medium', 'high'
    calories INTEGER,
    metadata JSONB,
    PRIMARY KEY (timestamp, activity_type)
);

SELECT create_hypertable('activity_events', 'timestamp');

-- Screen time tracking
CREATE TABLE screen_time (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    app_name TEXT,
    category TEXT, -- 'work', 'social', 'entertainment', 'productivity'
    duration INTEGER, -- seconds
    PRIMARY KEY (timestamp, device_id, app_name)
);

SELECT create_hypertable('screen_time', 'timestamp');
CREATE INDEX idx_screen_time_device ON screen_time(device_id, timestamp DESC);

-- Work hours tracking
CREATE TABLE work_sessions (
    session_id TEXT PRIMARY KEY,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ,
    device_id TEXT NOT NULL,
    calendar_integrated BOOLEAN DEFAULT FALSE, -- Was this scheduled work time?
    total_hours NUMERIC,
    metadata JSONB
);

SELECT create_hypertable('work_sessions', 'start_time');

-- Device state changes (smart home)
CREATE TABLE device_states (
    timestamp TIMESTAMPTZ NOT NULL,
    device_id TEXT NOT NULL,
    state TEXT NOT NULL, -- 'on', 'off', 'dimmed', etc.
    state_value NUMERIC, -- brightness, temperature, etc.
    triggered_by TEXT, -- 'automation', 'manual', 'agent'
    PRIMARY KEY (timestamp, device_id)
);

SELECT create_hypertable('device_states', 'timestamp');
CREATE INDEX idx_device_states_device ON device_states(device_id, timestamp DESC);

-- Gamification events
CREATE TABLE xp_events (
    timestamp TIMESTAMPTZ NOT NULL,
    agent TEXT NOT NULL,
    event_type TEXT NOT NULL, -- 'streak_continue', 'goal_complete', 'achievement_unlock'
    xp_amount INTEGER NOT NULL,
    description TEXT,
    metadata JSONB,
    PRIMARY KEY (timestamp, agent, event_type)
);

SELECT create_hypertable('xp_events', 'timestamp');
```

### 2.4 Backup Strategy

**SQLite Backup:**
```bash
#!/bin/bash
# /opt/lifeops/scripts/backup-sqlite.sh

BACKUP_DIR="/data/lifeops/backups/sqlite"
DB_FILE="/data/lifeops/db/lifeops.db"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Use SQLite backup API (online backup, no lock)
sqlite3 "$DB_FILE" ".backup '$BACKUP_DIR/lifeops_$TIMESTAMP.db'"

# Compress
gzip "$BACKUP_DIR/lifeops_$TIMESTAMP.db"

# Keep only last 30 days of daily backups
find "$BACKUP_DIR" -name "lifeops_*.db.gz" -mtime +30 -delete

# Sync to other locations (optional, if cabin PC is reachable)
# rsync -avz "$BACKUP_DIR/" cabin-user@summer-cabin:/data/lifeops/backups/sqlite/
```

**TimescaleDB Backup:**
```bash
#!/bin/bash
# /opt/lifeops/scripts/backup-timescale.sh

BACKUP_DIR="/data/lifeops/backups/tsdb"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# PostgreSQL dump with custom format (smaller, faster restore)
docker exec lifeops-timescale pg_dump -U lifeops -Fc lifeops_metrics > "$BACKUP_DIR/tsdb_$TIMESTAMP.dump"

# Keep only last 14 days (time-series data less critical for long-term backup)
find "$BACKUP_DIR" -name "tsdb_*.dump" -mtime +14 -delete
```

**Automated Schedule (systemd timer or cron):**
```
# Daily at 3 AM
0 3 * * * /opt/lifeops/scripts/backup-sqlite.sh
0 3 * * * /opt/lifeops/scripts/backup-timescale.sh
```

**Backup to Cloud (optional, encrypted):**
```bash
# Encrypted backup to B2/S3 (privacy preserved)
# Using rclone with crypt remote
rclone sync /data/lifeops/backups/ b2-encrypted:lifeops-backups/
```

---

## 3. API Architecture

### Hybrid REST + WebSocket Approach

**Design Philosophy:**
- **REST** for CRUD operations, queries, device control
- **WebSocket** for real-time updates, notifications, state sync
- **gRPC** considered but rejected (unnecessary complexity for this use case)

### 3.1 REST API

**Framework:** FastAPI (Python)

**Why FastAPI:**
- Excellent performance (async, comparable to Node.js/Go)
- Automatic OpenAPI/Swagger docs
- Pydantic validation (type safety)
- Native async/await
- Excellent ARM/Pi support
- Low resource usage

**API Structure:**

```python
# /opt/lifeops/api/main.py

from fastapi import FastAPI, HTTPException, Depends, WebSocket
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
import sqlite3
import asyncpg
from datetime import datetime

app = FastAPI(title="LifeOps API", version="1.0.0")

# ===== AUTHENTICATION =====
security = HTTPBearer()

async def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # Device-based JWT tokens
    # Each device gets a token, can be revoked via settings table
    token = credentials.credentials
    # Verify token (implementation details omitted)
    return {"device_id": "verified_device_id"}

# ===== HEALTH ENDPOINTS =====

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat()
    }

# ===== DEVICE ENDPOINTS =====

class Device(BaseModel):
    device_id: str
    device_name: str
    device_type: str
    location: Optional[str]
    ecosystem: str
    capabilities: List[str]

@app.get("/api/v1/devices", response_model=List[Device])
async def list_devices(auth = Depends(verify_token)):
    # Query SQLite devices table
    # Return list of devices
    pass

@app.get("/api/v1/devices/{device_id}", response_model=Device)
async def get_device(device_id: str, auth = Depends(verify_token)):
    # Get specific device
    pass

@app.post("/api/v1/devices/{device_id}/control")
async def control_device(device_id: str, command: dict, auth = Depends(verify_token)):
    # Control smart home device (lights, speakers, etc.)
    # Route command to appropriate integration
    pass

# ===== CALENDAR ENDPOINTS =====

class CalendarEvent(BaseModel):
    event_id: str
    source: str
    title: str
    start_time: datetime
    end_time: datetime
    all_day: bool
    location: Optional[str]
    description: Optional[str]

@app.get("/api/v1/calendar/events", response_model=List[CalendarEvent])
async def get_calendar_events(
    start: datetime,
    end: datetime,
    sources: Optional[List[str]] = None,
    auth = Depends(verify_token)
):
    # Query calendar_events table
    # Filter by time range and sources
    pass

@app.post("/api/v1/calendar/sync")
async def sync_calendars(auth = Depends(verify_token)):
    # Trigger manual calendar sync from all sources
    # Returns sync status
    pass

# ===== HEALTH METRICS ENDPOINTS =====

class HealthMetric(BaseModel):
    timestamp: datetime
    metric_type: str
    value: float
    metadata: Optional[dict]

@app.get("/api/v1/health/metrics", response_model=List[HealthMetric])
async def get_health_metrics(
    metric_type: str,
    start: datetime,
    end: datetime,
    auth = Depends(verify_token)
):
    # Query TimescaleDB health_metrics table
    # Return time-series data
    pass

@app.get("/api/v1/health/sleep/latest")
async def get_latest_sleep(auth = Depends(verify_token)):
    # Get most recent sleep session from Oura
    # Return readiness, sleep score, HRV
    pass

@app.get("/api/v1/health/readiness")
async def get_readiness(auth = Depends(verify_token)):
    # Current readiness score for Fitness Agent
    pass

# ===== AGENT ENDPOINTS =====

@app.get("/api/v1/agents")
async def list_agents(auth = Depends(verify_token)):
    # List all agents and their status
    pass

@app.get("/api/v1/agents/{agent_id}/state")
async def get_agent_state(agent_id: str, auth = Depends(verify_token)):
    # Get agent's current state from SQLite
    pass

@app.post("/api/v1/agents/{agent_id}/action")
async def trigger_agent_action(
    agent_id: str,
    action: dict,
    auth = Depends(verify_token)
):
    # Trigger specific agent action
    # Example: sleep_agent.start_winddown()
    pass

# ===== AUTOMATION ENDPOINTS =====

class AutomationRule(BaseModel):
    rule_id: str
    name: str
    agent: str
    trigger_type: str
    trigger_config: dict
    action_config: dict
    enabled: bool

@app.get("/api/v1/automations", response_model=List[AutomationRule])
async def list_automations(auth = Depends(verify_token)):
    pass

@app.post("/api/v1/automations", response_model=AutomationRule)
async def create_automation(rule: AutomationRule, auth = Depends(verify_token)):
    pass

@app.put("/api/v1/automations/{rule_id}")
async def update_automation(
    rule_id: str,
    rule: AutomationRule,
    auth = Depends(verify_token)
):
    pass

@app.delete("/api/v1/automations/{rule_id}")
async def delete_automation(rule_id: str, auth = Depends(verify_token)):
    pass

# ===== NOTIFICATION ENDPOINTS =====

@app.get("/api/v1/notifications")
async def get_notifications(
    status: Optional[str] = None,
    auth = Depends(verify_token)
):
    # Get notification queue for device
    # Filter by status (pending, delivered, dismissed)
    pass

@app.post("/api/v1/notifications/{notification_id}/dismiss")
async def dismiss_notification(notification_id: str, auth = Depends(verify_token)):
    pass

# ===== GAMIFICATION ENDPOINTS =====

@app.get("/api/v1/gamification/xp")
async def get_xp_summary(auth = Depends(verify_token)):
    # Total XP, recent gains, level progress
    pass

@app.get("/api/v1/gamification/streaks")
async def get_streaks(auth = Depends(verify_token)):
    # Current streaks for all trackable habits
    pass

@app.get("/api/v1/gamification/achievements")
async def get_achievements(auth = Depends(verify_token)):
    # Unlocked achievements and progress toward locked ones
    pass

# ===== WEBSOCKET (see section 3.2) =====

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    # Real-time updates (see WebSocket section)
    pass
```

**OpenAPI Documentation:**
- Automatically generated at `/docs` (Swagger UI)
- JSON spec at `/openapi.json`
- Useful for generating client SDKs

### 3.2 WebSocket API

**Purpose:** Real-time bidirectional communication

**Use Cases:**
- Device state changes (lights turned on/off)
- Incoming notifications
- Calendar event updates
- Health metric updates (new Oura data)
- Agent actions (wind-down mode activated)
- Multi-device sync (user changes setting on iPad, updates iPhone)

**Protocol:**

```python
# WebSocket message format (JSON)

# Client -> Server (subscribe to updates)
{
    "type": "subscribe",
    "topics": ["devices", "notifications", "calendar", "health"]
}

# Server -> Client (state update)
{
    "type": "device_state",
    "device_id": "plejd_living_room_main",
    "state": "on",
    "brightness": 80,
    "timestamp": "2026-01-08T20:30:00Z"
}

# Server -> Client (notification)
{
    "type": "notification",
    "notification_id": "notif_12345",
    "agent": "sleep_agent",
    "priority": 2,
    "title": "Bedtime in 30 minutes",
    "body": "Start winding down for target sleep time",
    "action_url": "/agent/sleep/winddown"
}

# Client -> Server (send command)
{
    "type": "command",
    "device_id": "plejd_living_room_main",
    "action": "set_brightness",
    "value": 50
}

# Server -> Client (command acknowledgment)
{
    "type": "ack",
    "request_id": "req_67890",
    "status": "success"
}
```

**Implementation:**

```python
from fastapi import WebSocket, WebSocketDisconnect
from typing import List
import json
import asyncio

class ConnectionManager:
    def __init__(self):
        self.active_connections: List[WebSocket] = []
        self.subscriptions = {}  # {websocket: [topics]}

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)
        self.subscriptions[websocket] = []

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        if websocket in self.subscriptions:
            del self.subscriptions[websocket]

    async def subscribe(self, websocket: WebSocket, topics: List[str]):
        self.subscriptions[websocket] = topics

    async def broadcast(self, message: dict, topic: str = None):
        """Broadcast message to all subscribed clients"""
        for connection in self.active_connections:
            if topic is None or topic in self.subscriptions.get(connection, []):
                await connection.send_json(message)

    async def send_personal(self, websocket: WebSocket, message: dict):
        """Send message to specific client"""
        await websocket.send_json(message)

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            message = json.loads(data)

            if message["type"] == "subscribe":
                await manager.subscribe(websocket, message["topics"])
                await manager.send_personal(websocket, {
                    "type": "subscribed",
                    "topics": message["topics"]
                })

            elif message["type"] == "command":
                # Handle device command
                # Route to appropriate integration
                # Broadcast state change to all clients
                result = await handle_device_command(message)
                await manager.broadcast({
                    "type": "device_state",
                    "device_id": message["device_id"],
                    "state": result["state"],
                    "timestamp": datetime.utcnow().isoformat()
                }, topic="devices")

            elif message["type"] == "ping":
                await manager.send_personal(websocket, {"type": "pong"})

    except WebSocketDisconnect:
        manager.disconnect(websocket)
```

**WebSocket Scaling:**
- For single Pi, direct FastAPI WebSocket is sufficient
- If scaling needed (unlikely), use Redis pub/sub for multi-node WebSocket coordination

### 3.3 Authentication & Security

**Device-Based JWT Tokens:**

```python
import jwt
from datetime import datetime, timedelta
import secrets

SECRET_KEY = secrets.token_urlsafe(32)  # Store in environment variable
ALGORITHM = "HS256"

def create_device_token(device_id: str, device_name: str) -> str:
    """Create JWT token for a device"""
    payload = {
        "device_id": device_id,
        "device_name": device_name,
        "iat": datetime.utcnow(),
        "exp": datetime.utcnow() + timedelta(days=365)  # Long-lived for device tokens
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_device_token(token: str) -> dict:
    """Verify and decode JWT token"""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        # Check if device is revoked in SQLite
        # SELECT revoked FROM devices WHERE device_id = ?
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")
```

**Device Registration Flow:**

1. User opens LifeOps app on new device
2. App generates device ID (UUID) and device info
3. App makes registration request to `/api/v1/auth/register`
4. User approves registration on another device or web dashboard
5. Server generates JWT token for new device
6. Device stores token securely (iOS Keychain, macOS Keychain, Linux secret-service)
7. Device uses token for all API requests

**Network Security:**

- HTTPS/TLS for all REST API calls (Let's Encrypt cert on Pi)
- WSS (WebSocket Secure) for WebSocket connections
- mTLS (mutual TLS) optional for enhanced security between locations
- Local network only by default (no external exposure unless explicitly configured)

**VPN for Multi-Location:**
- WireGuard VPN between home and cabins
- All LifeOps traffic over encrypted VPN tunnel
- Avoids exposing API to public internet

---

## 4. Sync Strategy

### Multi-Location Challenge

**Scenario:**
- Primary Pi at home (always-on)
- Summer cabin PC (on when visiting, ~10 weekends/year)
- Winter cabin PC (on when visiting, ~6 weekends/year)
- Mobile devices (iPhone, iPad, Mac) always with user

**Requirements:**
- Work when at any location (offline-capable at cabin)
- Sync changes when locations connect
- No data loss from conflicts
- Eventual consistency acceptable

### Solution: Multi-Master CRDT Sync

**CRDT:** Conflict-free Replicated Data Types

**Strategy:**
1. Each location is a node with full database
2. Changes are tagged with node ID and logical clock (Lamport timestamp)
3. Nodes sync when network available (opportunistic)
4. CRDTs guarantee convergence without manual conflict resolution

**Implementation:**

### 4.1 CRDT for Settings (LWW-Element-Set)

**LWW:** Last-Write-Wins (simple, works for most settings)

```python
# sync_metadata table structure
CREATE TABLE sync_metadata (
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    version INTEGER NOT NULL,  # Logical clock (Lamport timestamp)
    node_id TEXT NOT NULL,     # Which node made this change
    updated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (table_name, record_id)
);

# Example: User changes bedtime at cabin
# Cabin node creates record:
INSERT INTO settings (key, value, updated_at) VALUES ('bedtime', '22:30', '2026-01-08 20:00:00');
INSERT INTO sync_metadata (table_name, record_id, version, node_id, updated_at)
VALUES ('settings', 'bedtime', 15, 'cabin_summer', '2026-01-08 20:00:00');

# When cabin syncs with home:
# - Compare version numbers
# - If home.version < cabin.version, update home
# - If home.version > cabin.version, keep home (already newer)
# - If home.version == cabin.version, compare timestamps (LWW)
```

**Sync Algorithm:**

```python
async def sync_table(local_conn, remote_conn, table_name: str):
    """Sync a table using LWW-CRDT"""

    # Get all records from remote that are newer than local
    remote_records = await remote_conn.fetch("""
        SELECT r.*, s.version, s.node_id, s.updated_at
        FROM {table} r
        JOIN sync_metadata s ON s.table_name = $1 AND s.record_id = r.{pk}
    """.format(table=table_name, pk=get_primary_key(table_name)), table_name)

    for remote_record in remote_records:
        # Check local version
        local_meta = await local_conn.fetchrow("""
            SELECT version, node_id, updated_at
            FROM sync_metadata
            WHERE table_name = $1 AND record_id = $2
        """, table_name, remote_record['id'])

        should_update = False
        if local_meta is None:
            should_update = True  # New record
        elif remote_record['version'] > local_meta['version']:
            should_update = True  # Remote is newer
        elif remote_record['version'] == local_meta['version']:
            # Same version, use timestamp (LWW)
            if remote_record['updated_at'] > local_meta['updated_at']:
                should_update = True

        if should_update:
            # Update local record
            await update_local_record(local_conn, table_name, remote_record)

    # Push local changes to remote (symmetric sync)
    # (same logic in reverse)
```

### 4.2 Sync Service

**Docker Service:**

```yaml
# docker-compose.yml
sync-service:
  build: ./services/sync
  volumes:
    - /data/lifeops/db:/data/db:ro  # Read-only access to local DB
  environment:
    - NODE_ID=${NODE_ID}  # 'home_pi', 'cabin_summer', 'cabin_winter'
    - SYNC_PEERS=${SYNC_PEERS}  # Comma-separated list of peer URLs
  deploy:
    resources:
      limits:
        cpus: '0.5'
        memory: 256M
```

**Sync Service Logic:**

```python
# /opt/lifeops/services/sync/sync_service.py

import asyncio
import aiohttp
from typing import List
import os

NODE_ID = os.getenv("NODE_ID", "home_pi")
SYNC_PEERS = os.getenv("SYNC_PEERS", "").split(",")
SYNC_INTERVAL = 300  # 5 minutes when peers available

class SyncService:
    def __init__(self):
        self.node_id = NODE_ID
        self.peers = [p for p in SYNC_PEERS if p]
        self.last_sync = {}  # {peer: timestamp}

    async def run(self):
        """Main sync loop"""
        while True:
            for peer in self.peers:
                try:
                    await self.sync_with_peer(peer)
                except Exception as e:
                    print(f"Sync failed with {peer}: {e}")

            await asyncio.sleep(SYNC_INTERVAL)

    async def sync_with_peer(self, peer_url: str):
        """Sync with a specific peer"""
        async with aiohttp.ClientSession() as session:
            # Check if peer is reachable
            try:
                async with session.get(f"{peer_url}/health", timeout=5) as resp:
                    if resp.status != 200:
                        return  # Peer not available
            except:
                return  # Peer not reachable

            # Get peer's sync metadata
            async with session.get(f"{peer_url}/api/v1/sync/metadata") as resp:
                peer_metadata = await resp.json()

            # Compare with local metadata
            local_metadata = await self.get_local_metadata()

            # Determine what needs to sync
            to_pull = self.calculate_pull(local_metadata, peer_metadata)
            to_push = self.calculate_push(local_metadata, peer_metadata)

            # Pull changes from peer
            if to_pull:
                async with session.post(
                    f"{peer_url}/api/v1/sync/pull",
                    json={"records": to_pull}
                ) as resp:
                    changes = await resp.json()
                    await self.apply_changes(changes)

            # Push changes to peer
            if to_push:
                changes_to_push = await self.prepare_push(to_push)
                async with session.post(
                    f"{peer_url}/api/v1/sync/push",
                    json=changes_to_push
                ) as resp:
                    result = await resp.json()

            self.last_sync[peer_url] = datetime.utcnow()
            print(f"Synced with {peer_url}: pulled {len(to_pull)}, pushed {len(to_push)}")

    async def get_local_metadata(self) -> dict:
        """Get all sync metadata from local DB"""
        # Query sync_metadata table
        pass

    def calculate_pull(self, local: dict, remote: dict) -> List[dict]:
        """Determine which records to pull from remote"""
        to_pull = []
        for table, records in remote.items():
            for record_id, remote_meta in records.items():
                local_meta = local.get(table, {}).get(record_id)
                if local_meta is None or remote_meta["version"] > local_meta["version"]:
                    to_pull.append({
                        "table": table,
                        "record_id": record_id,
                        "version": remote_meta["version"]
                    })
        return to_pull

    def calculate_push(self, local: dict, remote: dict) -> List[dict]:
        """Determine which records to push to remote"""
        # Symmetric to calculate_pull
        pass

    async def apply_changes(self, changes: dict):
        """Apply synced changes to local database"""
        # Update SQLite with LWW logic
        pass

    async def prepare_push(self, to_push: List[dict]) -> dict:
        """Prepare local changes for pushing"""
        # Read records from local DB
        pass

if __name__ == "__main__":
    service = SyncService()
    asyncio.run(service.run())
```

### 4.3 TimescaleDB Sync (Time-Series Data)

**Problem:** Time-series data (health metrics) grows large, full sync impractical.

**Solution:** Incremental sync with time-based partitioning.

```python
async def sync_timeseries(peer_url: str, last_sync_time: datetime):
    """Sync only new time-series data since last sync"""

    # Get new records from peer since last_sync_time
    async with session.get(
        f"{peer_url}/api/v1/sync/timeseries",
        params={"since": last_sync_time.isoformat()}
    ) as resp:
        new_records = await resp.json()

    # Insert into local TimescaleDB
    async with asyncpg.create_pool(TSDB_DSN) as pool:
        async with pool.acquire() as conn:
            for record in new_records:
                # Insert or ignore (timestamps should be immutable)
                await conn.execute("""
                    INSERT INTO health_metrics (timestamp, metric_type, value, metadata, source)
                    VALUES ($1, $2, $3, $4, $5)
                    ON CONFLICT (timestamp, metric_type) DO NOTHING
                """, record['timestamp'], record['metric_type'], record['value'],
                    record['metadata'], record['source'])
```

**Key Insight:** Time-series data is append-only. Sync is simple: "give me everything after timestamp X."

### 4.4 Offline-First Mobile Apps

**Strategy:**
- Mobile apps have local SQLite cache
- Read from local cache (instant)
- Writes go to local cache + background sync to hub
- Queue API calls when offline, replay when online

```swift
// iOS example
class LifeOpsSync {
    let localDB: SQLite.Database
    let apiClient: APIClient
    let syncQueue: OperationQueue

    func saveSetting(key: String, value: String) {
        // Write to local DB immediately
        try localDB.run(settings.insert(or: .replace, key <- key, value <- value))

        // Queue API call
        syncQueue.addOperation {
            do {
                try await self.apiClient.updateSetting(key: key, value: value)
                // Mark as synced
            } catch {
                // Retry later
                self.queueForRetry(key: key, value: value)
            }
        }
    }

    func getSetting(key: String) -> String? {
        // Always read from local DB (instant)
        return try? localDB.pluck(settings.filter(key == key))
    }
}
```

### 4.5 Sync Performance

**Expected Sync Load:**

| Data Type | Size per Day | Retention | Total Size |
|-----------|--------------|-----------|------------|
| Settings | ~1KB | Forever | ~1MB |
| Calendar events | ~10KB | 2 years | ~7MB |
| Health metrics (raw) | ~500KB | 90 days | ~45MB |
| Health metrics (aggregated) | ~50KB | 2 years | ~37MB |
| Screen time | ~100KB | 90 days | ~9MB |
| Work sessions | ~50KB | 90 days | ~4.5MB |
| Device states | ~200KB | 30 days | ~6MB |
| XP events | ~20KB | Forever | ~7MB |

**Total per location:** ~120MB for full sync (initial), then ~1-2MB/day incremental.

**Bandwidth:**
- Initial sync: 120MB (acceptable on typical home network, ~1 minute)
- Daily sync: 1-2MB (negligible, ~few seconds)
- Mobile sync: Only settings and calendar (small, ~100KB)

---

## 5. Containerization & Deployment

### Docker Compose Stack

**File:** `/opt/lifeops/docker-compose.yml`

```yaml
version: '3.8'

services:
  # ===== DATABASES =====

  timescale:
    image: timescale/timescaledb:latest-pg16
    container_name: lifeops-timescale
    restart: unless-stopped
    volumes:
      - /data/lifeops/tsdb:/var/lib/postgresql/data
    environment:
      POSTGRES_DB: lifeops_metrics
      POSTGRES_USER: lifeops
      POSTGRES_PASSWORD: ${TSDB_PASSWORD}
    shm_size: 256mb
    ports:
      - "127.0.0.1:5432:5432"  # Only accessible locally
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 512M
    networks:
      - lifeops-net

  # ===== API SERVER =====

  api:
    build: ./services/api
    container_name: lifeops-api
    restart: unless-stopped
    volumes:
      - /data/lifeops/db:/data/db
      - /data/lifeops/config:/config
    environment:
      - DATABASE_PATH=/data/db/lifeops.db
      - TSDB_HOST=timescale
      - TSDB_PORT=5432
      - TSDB_USER=lifeops
      - TSDB_PASSWORD=${TSDB_PASSWORD}
      - TSDB_DATABASE=lifeops_metrics
      - JWT_SECRET=${JWT_SECRET}
      - NODE_ID=${NODE_ID}
    ports:
      - "8000:8000"  # API port
    depends_on:
      - timescale
    deploy:
      resources:
        limits:
          cpus: '1.5'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 256M
    networks:
      - lifeops-net

  # ===== AGENT ORCHESTRATOR =====

  orchestrator:
    build: ./services/orchestrator
    container_name: lifeops-orchestrator
    restart: unless-stopped
    volumes:
      - /data/lifeops/db:/data/db
      - /data/lifeops/config:/config
    environment:
      - DATABASE_PATH=/data/db/lifeops.db
      - TSDB_HOST=timescale
      - TSDB_PORT=5432
      - TSDB_USER=lifeops
      - TSDB_PASSWORD=${TSDB_PASSWORD}
      - TSDB_DATABASE=lifeops_metrics
      - API_HOST=api
      - API_PORT=8000
      - NODE_ID=${NODE_ID}
    depends_on:
      - api
      - timescale
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 128M
    networks:
      - lifeops-net

  # ===== SYNC SERVICE =====

  sync:
    build: ./services/sync
    container_name: lifeops-sync
    restart: unless-stopped
    volumes:
      - /data/lifeops/db:/data/db
    environment:
      - DATABASE_PATH=/data/db/lifeops.db
      - NODE_ID=${NODE_ID}
      - SYNC_PEERS=${SYNC_PEERS}
      - API_HOST=api
      - API_PORT=8000
    depends_on:
      - api
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
        reservations:
          cpus: '0.1'
          memory: 64M
    networks:
      - lifeops-net

  # ===== INTEGRATIONS =====

  oura-sync:
    build: ./services/integrations/oura
    container_name: lifeops-oura-sync
    restart: unless-stopped
    environment:
      - OURA_ACCESS_TOKEN=${OURA_ACCESS_TOKEN}
      - TSDB_HOST=timescale
      - TSDB_PORT=5432
      - TSDB_USER=lifeops
      - TSDB_PASSWORD=${TSDB_PASSWORD}
      - TSDB_DATABASE=lifeops_metrics
      - SYNC_INTERVAL=300  # 5 minutes
    depends_on:
      - timescale
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
    networks:
      - lifeops-net

  calendar-sync:
    build: ./services/integrations/calendar
    container_name: lifeops-calendar-sync
    restart: unless-stopped
    volumes:
      - /data/lifeops/db:/data/db
      - /data/lifeops/config:/config
    environment:
      - DATABASE_PATH=/data/db/lifeops.db
      - ICLOUD_USER=${ICLOUD_USER}
      - ICLOUD_PASSWORD=${ICLOUD_PASSWORD}
      - GOOGLE_CREDENTIALS=/config/google-credentials.json
      - OUTLOOK_CREDENTIALS=/config/outlook-credentials.json
      - SYNC_INTERVAL=600  # 10 minutes
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M
    networks:
      - lifeops-net

  plejd-bridge:
    build: ./services/integrations/plejd
    container_name: lifeops-plejd-bridge
    restart: unless-stopped
    privileged: true  # Needs Bluetooth access
    network_mode: host  # Needs host Bluetooth
    volumes:
      - /var/run/dbus:/var/run/dbus
      - /data/lifeops/db:/data/db
    environment:
      - DATABASE_PATH=/data/db/lifeops.db
      - PLEJD_CRYPTO_KEY=${PLEJD_CRYPTO_KEY}
      - PLEJD_SITE_ID=${PLEJD_SITE_ID}
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 128M

  # ===== WEB DASHBOARD (OPTIONAL) =====

  dashboard:
    build: ./services/dashboard
    container_name: lifeops-dashboard
    restart: unless-stopped
    ports:
      - "8080:80"
    environment:
      - API_URL=http://api:8000
    depends_on:
      - api
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 256M
    networks:
      - lifeops-net

  # ===== REVERSE PROXY (HTTPS) =====

  nginx:
    image: nginx:alpine
    container_name: lifeops-nginx
    restart: unless-stopped
    ports:
      - "443:443"
      - "80:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - /data/lifeops/certs:/etc/nginx/certs:ro
    depends_on:
      - api
      - dashboard
    deploy:
      resources:
        limits:
          cpus: '0.25'
          memory: 64M
    networks:
      - lifeops-net

networks:
  lifeops-net:
    driver: bridge

volumes:
  timescale-data:
```

**Environment Variables:**

```bash
# /opt/lifeops/.env

# Node identification
NODE_ID=home_pi  # Or 'cabin_summer', 'cabin_winter'

# Database
TSDB_PASSWORD=<generate_strong_password>

# API
JWT_SECRET=<generate_strong_secret>

# Sync
SYNC_PEERS=https://cabin-summer.local:443,https://cabin-winter.local:443

# Integrations
OURA_ACCESS_TOKEN=<from_oura_api>
ICLOUD_USER=<icloud_email>
ICLOUD_PASSWORD=<icloud_app_specific_password>
# Google and Outlook use OAuth JSON files in /config

# Plejd
PLEJD_CRYPTO_KEY=<from_plejd_app>
PLEJD_SITE_ID=<from_plejd_app>
```

### Resource Allocation Summary

| Service | CPU Limit | Memory Limit | Purpose |
|---------|-----------|--------------|---------|
| TimescaleDB | 2.0 cores | 2GB | Time-series database |
| API | 1.5 cores | 1GB | REST + WebSocket API |
| Orchestrator | 1.0 core | 512MB | Agent coordination |
| Sync | 0.5 core | 256MB | Multi-location sync |
| Oura Sync | 0.25 core | 128MB | Oura API polling |
| Calendar Sync | 0.25 core | 128MB | Calendar aggregation |
| Plejd Bridge | 0.25 core | 128MB | Bluetooth lighting control |
| Dashboard | 0.5 core | 256MB | Web interface |
| Nginx | 0.25 core | 64MB | Reverse proxy/TLS |

**Total Resources:**
- CPU: ~6.5 cores (Pi 5 has 4, will share time-sliced)
- Memory: ~4.4GB (Pi has 8GB, comfortable)
- Storage I/O: Mostly TimescaleDB (hence SSD requirement)

**Actual Load (Expected):**
- Idle: ~20% CPU, ~2GB RAM
- Active use: ~40% CPU, ~3GB RAM
- Heavy sync: ~60% CPU, ~4GB RAM

**Conclusion:** Raspberry Pi 5 (8GB) is more than sufficient.

---

## 6. Service Architecture Details

### 6.1 Agent Orchestrator

**Purpose:** Runs all Life Domain Agents and Technical Agents

**Architecture:**

```python
# /opt/lifeops/services/orchestrator/main.py

import asyncio
from typing import Dict, Type
from agents.base import Agent
from agents.sleep_agent import SleepAgent
from agents.fitness_agent import FitnessAgent
from agents.work_life_agent import WorkLifeAgent
from agents.screen_time_agent import ScreenTimeAgent
# ... import all agents

class Orchestrator:
    def __init__(self):
        self.agents: Dict[str, Agent] = {}
        self.event_bus = EventBus()  # Pub/sub for inter-agent communication
        self.scheduler = AsyncScheduler()  # For time-based triggers

    async def start(self):
        """Initialize and start all agents"""

        # Initialize agents
        self.agents = {
            'sleep': SleepAgent(self.event_bus, self.scheduler),
            'fitness': FitnessAgent(self.event_bus, self.scheduler),
            'work_life': WorkLifeAgent(self.event_bus, self.scheduler),
            'screen_time': ScreenTimeAgent(self.event_bus, self.scheduler),
            'home': HomeAgent(self.event_bus, self.scheduler),
            'entertainment': EntertainmentAgent(self.event_bus, self.scheduler),
            'social': SocialAgent(self.event_bus, self.scheduler),
            'cabin': CabinAgent(self.event_bus, self.scheduler),
            'nutrition': NutritionAgent(self.event_bus, self.scheduler),
            'finance': FinanceAgent(self.event_bus, self.scheduler),
            # Technical agents
            'integration': IntegrationAgent(self.event_bus, self.scheduler),
            'notification': NotificationAgent(self.event_bus, self.scheduler),
            'automation': AutomationAgent(self.event_bus, self.scheduler),
            'data': DataAgent(self.event_bus, self.scheduler),
        }

        # Start all agents
        tasks = [agent.start() for agent in self.agents.values()]
        await asyncio.gather(*tasks)

    async def stop(self):
        """Gracefully stop all agents"""
        tasks = [agent.stop() for agent in self.agents.values()]
        await asyncio.gather(*tasks)

    def get_agent(self, agent_id: str) -> Agent:
        """Get agent by ID"""
        return self.agents.get(agent_id)

class EventBus:
    """Simple pub/sub for agent communication"""
    def __init__(self):
        self.subscribers = {}  # {event_type: [callbacks]}

    def subscribe(self, event_type: str, callback):
        if event_type not in self.subscribers:
            self.subscribers[event_type] = []
        self.subscribers[event_type].append(callback)

    async def publish(self, event_type: str, data: dict):
        if event_type in self.subscribers:
            tasks = [callback(data) for callback in self.subscribers[event_type]]
            await asyncio.gather(*tasks)

class AsyncScheduler:
    """Cron-like scheduler for time-based agent triggers"""
    def __init__(self):
        self.tasks = []

    def schedule(self, cron_expr: str, callback):
        """Schedule callback with cron expression"""
        # Use APScheduler or similar
        pass

    def schedule_once(self, when: datetime, callback):
        """Schedule one-time callback"""
        pass

# Main entry point
if __name__ == "__main__":
    orchestrator = Orchestrator()
    asyncio.run(orchestrator.start())
```

**Agent Base Class:**

```python
# /opt/lifeops/services/orchestrator/agents/base.py

from abc import ABC, abstractmethod
import asyncio

class Agent(ABC):
    def __init__(self, event_bus, scheduler):
        self.event_bus = event_bus
        self.scheduler = scheduler
        self.state = {}  # Agent-specific state
        self.running = False

    @abstractmethod
    async def initialize(self):
        """Initialize agent (load state, set up subscriptions)"""
        pass

    @abstractmethod
    async def run(self):
        """Main agent loop"""
        pass

    async def start(self):
        """Start the agent"""
        await self.initialize()
        self.running = True
        asyncio.create_task(self.run())

    async def stop(self):
        """Stop the agent"""
        self.running = False
        await self.cleanup()

    async def cleanup(self):
        """Cleanup resources"""
        pass

    async def handle_event(self, event_type: str, data: dict):
        """Handle incoming events from event bus"""
        pass

    async def emit_event(self, event_type: str, data: dict):
        """Emit event to other agents"""
        await self.event_bus.publish(event_type, data)

    async def save_state(self):
        """Persist agent state to database"""
        # Save self.state to SQLite agent_state table
        pass

    async def load_state(self):
        """Load agent state from database"""
        # Load self.state from SQLite
        pass
```

**Example: Sleep Agent:**

```python
# /opt/lifeops/services/orchestrator/agents/sleep_agent.py

from agents.base import Agent
from datetime import datetime, time, timedelta

class SleepAgent(Agent):
    async def initialize(self):
        """Initialize Sleep Agent"""
        await self.load_state()

        # Default settings
        if 'target_bedtime' not in self.state:
            self.state['target_bedtime'] = '22:30'
        if 'target_wake_time' not in self.state:
            self.state['target_wake_time'] = '06:30'
        if 'winddown_start_offset' not in self.state:
            self.state['winddown_start_offset'] = 30  # minutes before bedtime

        # Subscribe to relevant events
        self.event_bus.subscribe('oura_sleep_updated', self.on_sleep_data_updated)
        self.event_bus.subscribe('device_screen_on', self.on_screen_activity)

        # Schedule daily triggers
        bedtime = datetime.strptime(self.state['target_bedtime'], '%H:%M').time()
        winddown_time = (datetime.combine(datetime.today(), bedtime) -
                         timedelta(minutes=self.state['winddown_start_offset'])).time()

        self.scheduler.schedule(f"{winddown_time.hour}:{winddown_time.minute}",
                                self.trigger_winddown)
        self.scheduler.schedule(f"{bedtime.hour}:{bedtime.minute}",
                                self.trigger_bedtime_reminder)

    async def run(self):
        """Main Sleep Agent loop"""
        while self.running:
            # Check sleep goals
            await self.check_sleep_goals()

            # Monitor late-night screen time
            await self.monitor_late_night_activity()

            # Sleep every 60 seconds
            await asyncio.sleep(60)

    async def trigger_winddown(self):
        """Start wind-down mode"""
        print(f"[SleepAgent] Starting wind-down mode")

        # Emit event to dim lights
        await self.emit_event('home_scene_trigger', {
            'scene': 'winddown',
            'brightness': 30,
            'color_temp': 'warm'
        })

        # Send notification
        await self.emit_event('notification_send', {
            'agent': 'sleep',
            'priority': 2,  # Important
            'title': 'Wind Down Time',
            'body': f"Bedtime in {self.state['winddown_start_offset']} minutes",
            'action_url': '/agent/sleep/winddown'
        })

    async def trigger_bedtime_reminder(self):
        """Remind user of bedtime"""
        print(f"[SleepAgent] Bedtime reminder")

        await self.emit_event('notification_send', {
            'agent': 'sleep',
            'priority': 2,
            'title': 'Bedtime',
            'body': f"Target bedtime: {self.state['target_bedtime']}",
            'action_url': '/agent/sleep/bedtime'
        })

    async def on_sleep_data_updated(self, data: dict):
        """Handle new sleep data from Oura"""
        print(f"[SleepAgent] New sleep data: score={data['score']}")

        # Analyze sleep quality
        if data['score'] < 70:
            # Poor sleep, suggest earlier bedtime
            await self.emit_event('notification_send', {
                'agent': 'sleep',
                'priority': 3,
                'title': 'Sleep Quality Alert',
                'body': f"Last night's sleep score: {data['score']}/100. Consider earlier bedtime tonight.",
            })

        # Update sleep history for trend analysis
        # (Data Agent handles storage)

    async def on_screen_activity(self, data: dict):
        """Monitor late-night screen activity"""
        now = datetime.now().time()
        bedtime = datetime.strptime(self.state['target_bedtime'], '%H:%M').time()

        if now > bedtime:
            # User active past bedtime
            minutes_past = (datetime.combine(datetime.today(), now) -
                            datetime.combine(datetime.today(), bedtime)).seconds // 60

            if minutes_past > 30:
                await self.emit_event('notification_send', {
                    'agent': 'sleep',
                    'priority': 2,
                    'title': 'Late Night Activity',
                    'body': f"Still awake {minutes_past} minutes past bedtime.",
                    'action_url': '/agent/sleep/status'
                })

    async def check_sleep_goals(self):
        """Check if sleep goals are being met"""
        # Query TimescaleDB for recent sleep data
        # Analyze trends
        # Provide weekly summaries
        pass

    async def monitor_late_night_activity(self):
        """Monitor screen activity past bedtime"""
        pass
```

### 6.2 Integration Services

**Oura Ring Sync:**

```python
# /opt/lifeops/services/integrations/oura/sync.py

import asyncio
import httpx
import asyncpg
from datetime import datetime, timedelta
import os

OURA_ACCESS_TOKEN = os.getenv("OURA_ACCESS_TOKEN")
OURA_API_BASE = "https://api.ouraring.com/v2/usercollection"
SYNC_INTERVAL = int(os.getenv("SYNC_INTERVAL", "300"))  # 5 minutes

class OuraSync:
    def __init__(self):
        self.client = httpx.AsyncClient(
            headers={"Authorization": f"Bearer {OURA_ACCESS_TOKEN}"}
        )
        self.db_pool = None

    async def initialize(self):
        """Connect to TimescaleDB"""
        self.db_pool = await asyncpg.create_pool(
            host=os.getenv("TSDB_HOST"),
            port=int(os.getenv("TSDB_PORT")),
            user=os.getenv("TSDB_USER"),
            password=os.getenv("TSDB_PASSWORD"),
            database=os.getenv("TSDB_DATABASE")
        )

    async def run(self):
        """Main sync loop"""
        while True:
            try:
                await self.sync_sleep()
                await self.sync_readiness()
                await self.sync_activity()
                await self.sync_daily_metrics()
            except Exception as e:
                print(f"[OuraSync] Error: {e}")

            await asyncio.sleep(SYNC_INTERVAL)

    async def sync_sleep(self):
        """Sync sleep sessions"""
        # Get sleep data for last 7 days
        start_date = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
        end_date = datetime.now().strftime("%Y-%m-%d")

        response = await self.client.get(
            f"{OURA_API_BASE}/sleep",
            params={"start_date": start_date, "end_date": end_date}
        )
        data = response.json()

        async with self.db_pool.acquire() as conn:
            for session in data.get("data", []):
                # Insert sleep session
                await conn.execute("""
                    INSERT INTO sleep_sessions (
                        session_id, start_time, end_time,
                        total_sleep_duration, efficiency,
                        deep_sleep, rem_sleep, light_sleep, awake, latency,
                        hrv_average, resting_hr_average, temperature_deviation,
                        score, metadata
                    ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
                    ON CONFLICT (session_id) DO UPDATE SET
                        end_time = EXCLUDED.end_time,
                        score = EXCLUDED.score,
                        metadata = EXCLUDED.metadata
                """,
                    session["id"],
                    datetime.fromisoformat(session["bedtime_start"]),
                    datetime.fromisoformat(session["bedtime_end"]),
                    session["total_sleep_duration"],
                    session["efficiency"],
                    session.get("deep_sleep_duration", 0),
                    session.get("rem_sleep_duration", 0),
                    session.get("light_sleep_duration", 0),
                    session.get("awake_time", 0),
                    session.get("latency", 0),
                    session.get("average_hrv", 0),
                    session.get("lowest_heart_rate", 0),
                    session.get("temperature_deviation", 0),
                    session.get("score", 0),
                    json.dumps(session)  # Full data as JSON
                )

                # Emit event for agents
                # (via API call to orchestrator event bus)

    async def sync_readiness(self):
        """Sync readiness scores"""
        # Similar to sleep sync
        pass

    async def sync_activity(self):
        """Sync activity data"""
        pass

    async def sync_daily_metrics(self):
        """Sync daily summary metrics"""
        # Heart rate, HRV, temperature, etc.
        pass

if __name__ == "__main__":
    sync = OuraSync()
    asyncio.run(sync.initialize())
    asyncio.run(sync.run())
```

**Calendar Sync:**

```python
# /opt/lifeops/services/integrations/calendar/sync.py

import asyncio
import sqlite3
from datetime import datetime, timedelta
from icalendar import Calendar
import httpx
# Import iCloud, Google, Outlook calendar libraries

class CalendarSync:
    def __init__(self):
        self.db_path = os.getenv("DATABASE_PATH")
        self.sync_interval = int(os.getenv("SYNC_INTERVAL", "600"))  # 10 minutes

        # Initialize calendar clients
        self.icloud = iCloudCalendar()  # pyicloud
        self.google = GoogleCalendar()  # google-calendar-api
        self.outlook = OutlookCalendar()  # O365 library

    async def run(self):
        """Main sync loop"""
        while True:
            try:
                await self.sync_all_calendars()
            except Exception as e:
                print(f"[CalendarSync] Error: {e}")

            await asyncio.sleep(self.sync_interval)

    async def sync_all_calendars(self):
        """Sync all calendar sources"""
        tasks = [
            self.sync_calendar('icloud', self.icloud),
            self.sync_calendar('google', self.google),
            self.sync_calendar('outlook', self.outlook),
        ]
        await asyncio.gather(*tasks)

    async def sync_calendar(self, source: str, client):
        """Sync a specific calendar"""
        # Get events for next 30 days
        start = datetime.now()
        end = start + timedelta(days=30)

        events = await client.get_events(start, end)

        # Update SQLite
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        for event in events:
            cursor.execute("""
                INSERT OR REPLACE INTO calendar_events (
                    event_id, source, title, start_time, end_time,
                    all_day, location, description, metadata, synced_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                f"{source}_{event.id}",
                source,
                event.title,
                event.start,
                event.end,
                event.all_day,
                event.location,
                event.description,
                json.dumps(event.raw),
                datetime.now()
            ))

        conn.commit()
        conn.close()

        print(f"[CalendarSync] Synced {len(events)} events from {source}")
```

**Plejd Bluetooth Bridge:**

```python
# /opt/lifeops/services/integrations/plejd/bridge.py

import asyncio
from bleak import BleakScanner, BleakClient
import os

PLEJD_CRYPTO_KEY = os.getenv("PLEJD_CRYPTO_KEY")

class PlejdBridge:
    def __init__(self):
        self.devices = {}  # {address: BleakClient}
        self.running = False

    async def start(self):
        """Discover and connect to Plejd devices"""
        self.running = True

        # Scan for Plejd devices
        devices = await BleakScanner.discover()
        plejd_devices = [d for d in devices if "Plejd" in (d.name or "")]

        print(f"[PlejdBridge] Found {len(plejd_devices)} Plejd devices")

        # Connect to each device
        for device in plejd_devices:
            client = BleakClient(device.address)
            await client.connect()
            self.devices[device.address] = client

        # Listen for API commands
        await self.listen_for_commands()

    async def listen_for_commands(self):
        """Listen for control commands from API"""
        # Subscribe to event bus or poll SQLite for commands
        while self.running:
            # Check for pending commands
            await asyncio.sleep(1)

    async def set_light(self, device_id: str, state: str, brightness: int = None):
        """Control a Plejd light"""
        # Send Bluetooth command
        # Plejd protocol: https://github.com/ha-plejd/pyplejd
        pass

    async def stop(self):
        """Disconnect all devices"""
        self.running = False
        for client in self.devices.values():
            await client.disconnect()
```

---

## 7. Performance & Resource Estimates

### 7.1 Expected System Load

**Idle State (no active use):**
- CPU: 10-15% (background syncs, monitoring)
- RAM: 1.5-2GB
- Disk I/O: <1 MB/s (occasional writes)
- Network: <100 KB/s (API polls, health checks)
- Power: ~6W

**Active Use (user interaction, multiple devices):**
- CPU: 30-50%
- RAM: 2.5-3.5GB
- Disk I/O: 2-5 MB/s
- Network: 500 KB/s - 1 MB/s
- Power: ~8W

**Heavy Sync (cabin connecting after week offline):**
- CPU: 60-80%
- RAM: 3.5-4.5GB
- Disk I/O: 10-20 MB/s (temporary spike)
- Network: 5-10 MB/s (temporary spike)
- Power: ~10W

**Oura Sync (every 5 minutes):**
- HTTP request: ~50KB response
- Database insert: <1ms
- CPU spike: <1% for <1 second
- Negligible impact

### 7.2 Database Growth

**SQLite (Application DB):**
- Year 1: ~50MB
- Year 2: ~75MB
- Year 5: ~150MB
- Growth rate: ~25-30MB/year

**TimescaleDB (Metrics):**
- With compression and retention policies:
- Year 1: ~500MB (raw + aggregated)
- Year 2: ~800MB
- Year 5: ~1.5GB
- Growth rate: ~300MB/year after retention kicks in

**Total Storage (5 years):**
- Databases: ~2GB
- Backups: ~5GB (compressed, rotated)
- Logs: ~1GB (rotated)
- Total: ~8GB

**Recommendation:** 128GB SD card + 512GB SSD is overkill (good).

### 7.3 Network Bandwidth

**Daily Bandwidth (typical day at home):**
- Oura API: ~1MB/day (288 requests × 50KB)
- Calendar sync: ~500KB/day (144 requests × 3KB)
- Mobile app sync: ~10MB/day (various API calls)
- WebSocket keepalives: ~100KB/day
- Total: ~12MB/day

**Multi-location sync (weekend at cabin):**
- Initial sync: ~120MB (if first time, or month offline)
- Incremental daily: ~1-2MB
- Mobile sync: ~10MB/day
- Total: ~120MB initial, then ~10-15MB/day

**Yearly bandwidth:** ~5-10GB (negligible on any modern internet connection)

### 7.4 Scalability Limits

**Current architecture handles:**
- 1-10 users: No problem
- 10+ devices: No problem
- 3 locations: Designed for this
- 1M time-series records: ~200MB compressed (fine)
- 10M time-series records: ~2GB compressed (still fine)
- 100 API requests/minute: No problem
- 1000 API requests/minute: Might need optimization

**When to scale beyond Pi:**
- Multi-user deployment (family sharing)
- >1000 requests/minute sustained
- Real-time video processing
- Machine learning model training

**For this use case (single user, small household):** Raspberry Pi is perfect.

---

## 8. Deployment & Operations

### 8.1 Initial Setup

**1. Prepare Raspberry Pi:**

```bash
# Flash Raspberry Pi OS (64-bit, lite)
# Use Raspberry Pi Imager

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker pi

# Install Docker Compose
sudo apt install docker-compose-plugin

# Create data directories
sudo mkdir -p /data/lifeops/{db,tsdb,backups,config,certs}
sudo chown -R pi:pi /data/lifeops

# Mount SSD (if using external SSD for database)
# Add to /etc/fstab for automatic mount
```

**2. Clone LifeOps Repository:**

```bash
git clone https://github.com/yourusername/lifeops.git /opt/lifeops
cd /opt/lifeops
```

**3. Configure Environment:**

```bash
# Copy example env file
cp .env.example .env

# Edit with your settings
nano .env

# Generate secrets
python3 scripts/generate_secrets.py  # Creates JWT_SECRET, etc.
```

**4. Initialize Databases:**

```bash
# Create SQLite database with schema
sqlite3 /data/lifeops/db/lifeops.db < schemas/sqlite_schema.sql

# Start TimescaleDB and initialize
docker-compose up -d timescale
sleep 10  # Wait for PostgreSQL to start
docker exec -i lifeops-timescale psql -U lifeops -d lifeops_metrics < schemas/timescale_schema.sql
```

**5. Start Services:**

```bash
docker-compose up -d

# Check logs
docker-compose logs -f

# Verify health
curl http://localhost:8000/health
```

**6. Set Up Integrations:**

```bash
# Oura: Get access token from https://cloud.ouraring.com/personal-access-tokens
# Add to .env

# Calendars: Follow OAuth setup for Google and Outlook
python3 scripts/setup_google_calendar.py
python3 scripts/setup_outlook_calendar.py

# Plejd: Extract crypto key using Plejd app debug mode
# Add to .env
```

**7. Register Devices:**

```bash
# Generate device token for iPhone
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "iphone_primary",
    "device_name": "iPhone",
    "device_type": "mobile",
    "ecosystem": "apple"
  }'

# Copy token to iPhone app
```

### 8.2 Backup & Recovery

**Automated Backups (systemd timers):**

```bash
# /etc/systemd/system/lifeops-backup.timer
[Unit]
Description=LifeOps Daily Backup Timer

[Timer]
OnCalendar=daily
OnCalendar=03:00
Persistent=true

[Install]
WantedBy=timers.target

# /etc/systemd/system/lifeops-backup.service
[Unit]
Description=LifeOps Backup Service

[Service]
Type=oneshot
ExecStart=/opt/lifeops/scripts/backup.sh
User=pi

# Enable
sudo systemctl enable lifeops-backup.timer
sudo systemctl start lifeops-backup.timer
```

**Recovery Process:**

```bash
# Stop services
docker-compose down

# Restore SQLite
gunzip < /data/lifeops/backups/sqlite/lifeops_YYYYMMDD.db.gz > /data/lifeops/db/lifeops.db

# Restore TimescaleDB
docker-compose up -d timescale
sleep 10
docker exec -i lifeops-timescale pg_restore -U lifeops -d lifeops_metrics < /data/lifeops/backups/tsdb/tsdb_YYYYMMDD.dump

# Start services
docker-compose up -d
```

### 8.3 Monitoring

**Basic Health Checks:**

```bash
# Cron job to check services
# /etc/cron.d/lifeops-health

*/5 * * * * pi /opt/lifeops/scripts/health_check.sh
```

```bash
#!/bin/bash
# /opt/lifeops/scripts/health_check.sh

# Check API health
if ! curl -sf http://localhost:8000/health > /dev/null; then
    echo "LifeOps API is down!" | mail -s "LifeOps Alert" user@example.com
    docker-compose restart api
fi

# Check disk space
DISK_USAGE=$(df /data | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "LifeOps disk usage at ${DISK_USAGE}%" | mail -s "LifeOps Disk Alert" user@example.com
fi

# Check Docker containers
STOPPED=$(docker-compose ps --services --filter "status=exited")
if [ -n "$STOPPED" ]; then
    echo "LifeOps containers stopped: $STOPPED" | mail -s "LifeOps Container Alert" user@example.com
    docker-compose up -d
fi
```

**Logging:**

```yaml
# docker-compose.yml - Add to all services
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
```

**Prometheus + Grafana (Optional):**

```yaml
# docker-compose.yml - Add monitoring stack
prometheus:
  image: prom/prometheus
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    - /data/lifeops/prometheus:/prometheus
  ports:
    - "9090:9090"
  deploy:
    resources:
      limits:
        cpus: '0.25'
        memory: 128M

grafana:
  image: grafana/grafana
  volumes:
    - /data/lifeops/grafana:/var/lib/grafana
  ports:
    - "3000:3000"
  deploy:
    resources:
      limits:
        cpus: '0.25'
        memory: 128M
```

### 8.4 Updates & Maintenance

**Update LifeOps:**

```bash
cd /opt/lifeops
git pull origin main
docker-compose build
docker-compose up -d
```

**Database Maintenance:**

```bash
# SQLite
sqlite3 /data/lifeops/db/lifeops.db "VACUUM;"
sqlite3 /data/lifeops/db/lifeops.db "ANALYZE;"

# TimescaleDB
docker exec lifeops-timescale psql -U lifeops -d lifeops_metrics -c "VACUUM ANALYZE;"
```

**Log Rotation:**

```bash
# /etc/logrotate.d/lifeops
/data/lifeops/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 0640 pi pi
}
```

---

## 9. Security Considerations

### 9.1 Network Security

**Firewall (ufw):**

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 443/tcp   # HTTPS API
sudo ufw enable
```

**WireGuard VPN (for multi-location):**

```bash
# Install WireGuard on Pi
sudo apt install wireguard

# Generate keys
wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey

# Configure (example for home Pi as server)
# /etc/wireguard/wg0.conf
[Interface]
Address = 10.100.0.1/24
PrivateKey = <home_pi_private_key>
ListenPort = 51820

[Peer]
# Summer cabin
PublicKey = <summer_cabin_public_key>
AllowedIPs = 10.100.0.2/32

[Peer]
# Winter cabin
PublicKey = <winter_cabin_public_key>
AllowedIPs = 10.100.0.3/32

# Enable and start
sudo systemctl enable wg-quick@wg0
sudo systemctl start wg-quick@wg0
```

**TLS Certificates:**

```bash
# Option 1: Let's Encrypt (if domain available)
sudo apt install certbot
sudo certbot certonly --standalone -d lifeops.yourdomain.com

# Option 2: Self-signed (local network only)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /data/lifeops/certs/lifeops.key \
  -out /data/lifeops/certs/lifeops.crt
```

### 9.2 Data Security

**Encryption at Rest:**

```bash
# Option 1: Full disk encryption (LUKS)
# Set up during Pi OS installation

# Option 2: Encrypted database files
# SQLCipher for SQLite
# PostgreSQL TDE (Transparent Data Encryption)
```

**Secrets Management:**

```bash
# Use environment variables (never commit to git)
# Store .env outside repo
# Use Docker secrets for production

# Example: Docker secret
echo "your_secret_here" | docker secret create tsdb_password -
```

**API Key Rotation:**

```bash
# Rotate JWT secret
python3 scripts/rotate_jwt_secret.py

# Revoke device tokens
sqlite3 /data/lifeops/db/lifeops.db "UPDATE devices SET revoked = 1 WHERE device_id = 'old_device';"
```

### 9.3 Privacy

**Data Minimization:**
- Only collect data necessary for LifeOps features
- Automatic data aging (retention policies)
- User can export/delete all data anytime

**No External Data Sharing:**
- All data stays on self-hosted infrastructure
- No analytics, telemetry, or third-party tracking
- Integrations (Oura, calendars) use user's own API keys

**GDPR-like Principles:**
- Right to access (export API)
- Right to deletion (purge API)
- Data portability (JSON export)

---

## 10. Technology Stack Summary

### Core Stack

| Component | Technology | Rationale |
|-----------|-----------|-----------|
| **Operating System** | Raspberry Pi OS 64-bit | Optimized for Pi, Debian-based, stable |
| **Containerization** | Docker + Docker Compose | Easy deployment, resource limits, portability |
| **Application Database** | SQLite 3 | Zero-config, reliable, embedded, perfect for config |
| **Time-Series Database** | TimescaleDB (PostgreSQL) | Efficient compression, SQL familiarity, ARM support |
| **API Framework** | FastAPI (Python) | Async, fast, auto-docs, type-safe, low resource |
| **WebSocket** | FastAPI WebSocket | Built-in, no extra dependency |
| **Authentication** | JWT | Stateless, device-based, simple |
| **Sync Protocol** | Custom CRDT (LWW) | Conflict-free, multi-master, eventual consistency |
| **VPN** | WireGuard | Fast, modern, low overhead |
| **TLS** | Let's Encrypt / OpenSSL | Free, automated, industry standard |

### Integration Libraries

| Integration | Library | Language |
|-------------|---------|----------|
| Oura API | `httpx` | Python |
| iCloud Calendar | `pyicloud` | Python |
| Google Calendar | `google-api-python-client` | Python |
| Outlook Calendar | `O365` | Python |
| Plejd Bluetooth | `bleak` | Python |
| HomeKit | `homeassistant` integration | Python |
| Google Home | `pychromecast` | Python |
| SmartThings | `pysmartthings` | Python |

### Monitoring & Operations

| Purpose | Tool | Notes |
|---------|------|-------|
| Container orchestration | Docker Compose | Built-in, sufficient for single-node |
| Health checks | Custom scripts + cron | Lightweight, no overhead |
| Logging | Docker JSON logs | Rotated, compressed |
| Metrics (optional) | Prometheus + Grafana | If detailed metrics needed |
| Backups | rsync + cron | Simple, reliable |

---

## 11. Alternative Architectures Considered

### Rejected: Cloud-Hosted

**Why not AWS/GCP/Azure?**
- **Privacy concern:** Data leaves user control
- **Cost:** ~$20-50/month for comparable resources
- **Latency:** Slower than local network
- **Dependency:** Requires internet, not offline-capable
- **Philosophy:** Against LifeOps core value (privacy-first)

**When to consider:** If user wants remote access without VPN setup.

### Rejected: Kubernetes

**Why not K8s?**
- **Overkill:** Single node, 10 services, doesn't need orchestration
- **Resource overhead:** K8s control plane would use 30-40% of Pi resources
- **Complexity:** Steep learning curve for maintenance
- **Cost:** No benefit for single-user deployment

**When to consider:** Multi-user SaaS version of LifeOps.

### Rejected: Serverless (Lambda/Cloud Functions)

**Why not serverless?**
- **Privacy:** Cloud-hosted
- **Cost:** Would be expensive with frequent health data syncs
- **Cold starts:** Unacceptable latency for real-time control
- **Vendor lock-in:** Hard to self-host later

**When to consider:** Never for this use case.

### Rejected: Microservices (Separate VMs/Containers per Agent)

**Why not full microservices?**
- **Resource waste:** Each agent in own container = 10+ containers
- **Network overhead:** Inter-service calls instead of function calls
- **Complexity:** Service mesh, load balancers, etc.
- **Debugging:** Distributed tracing needed

**Compromise:** Docker Compose with logical service separation (API, Orchestrator, Integrations) is sufficient.

### Rejected: NoSQL (MongoDB, Cassandra)

**Why not NoSQL?**
- **SQLite/PostgreSQL are sufficient:** Relational model fits use case
- **Resource overhead:** NoSQL DBs generally use more RAM
- **Complexity:** Sharding, replication not needed for single-user
- **Familiarity:** SQL is well-known, easy to query

**When to consider:** If data model becomes very hierarchical (unlikely).

---

## 12. Future Enhancements

### Phase 2 Improvements (6-12 months)

1. **Machine Learning Models**
   - Local ML (TensorFlow Lite on Pi)
   - Sleep prediction: "You'll sleep poorly if you stay up"
   - Habit pattern recognition: "You work out more on Tuesdays"
   - Resource impact: +500MB storage, +10% CPU during training

2. **Voice Control**
   - Integration with HomePod / Google Home
   - "Hey Siri, start wind-down mode"
   - Resource impact: Minimal (API calls only)

3. **Advanced Gamification**
   - Detailed XP/level system
   - Achievements and badges
   - Leaderboards (self-competition over time)
   - Resource impact: +50MB database, negligible CPU

4. **Mobile App Enhancements**
   - Widget support (iOS/Android)
   - Apple Watch app
   - Real-time notifications
   - Resource impact: Client-side only

### Phase 3 (1-2 years)

1. **Multi-User Support**
   - Family sharing (partner, kids)
   - Separate profiles, shared home control
   - Resource impact: 2x database size, +20% CPU

2. **Advanced Automation**
   - If-this-then-that builder (visual)
   - Machine learning-driven automations
   - Location-based triggers
   - Resource impact: +100MB storage, +5% CPU

3. **Community Integrations**
   - Plugin system for custom integrations
   - Shared automation templates
   - Resource impact: Varies

### Phase 4 (2+ years)

1. **Federated Network**
   - Connect multiple LifeOps instances (friends, family)
   - Shared calendar visibility, coordinated routines
   - Resource impact: +20% network, minimal CPU

2. **AI Assistant**
   - Natural language queries: "How did I sleep last week?"
   - Proactive insights: "You sleep better when you work out"
   - Local LLM (Llama 3 8B on Pi 5 is feasible)
   - Resource impact: +5GB storage (model), +30% CPU during inference

---

## 13. Conclusion & Recommendation

### Final Architecture Summary

**Hardware:**
- **Primary Hub:** Raspberry Pi 5 (8GB RAM) with 512GB SSD
- **Fallback:** Linux PCs at each location (same stack)
- **Power:** ~6-10W typical (extremely efficient)
- **Cost:** ~$100 (you already own the Pi)

**Software:**
- **Databases:** SQLite (config) + TimescaleDB (metrics)
- **API:** FastAPI (REST + WebSocket)
- **Containerization:** Docker Compose (9 services)
- **Sync:** Multi-master CRDT (LWW) over VPN
- **Integrations:** Python-based services for Oura, calendars, smart home

**Resource Usage:**
- CPU: 20-40% typical, 60% peak
- RAM: 2-4GB typical (50% utilization on 8GB Pi)
- Storage: ~2GB first year, ~300MB/year growth
- Network: ~12MB/day typical, ~120MB cabin sync

**Key Strengths:**
1. **Privacy-first:** All data self-hosted, encrypted, under user control
2. **Efficient:** Runs comfortably on Pi 5, low power consumption
3. **Reliable:** Multi-location redundancy, automatic backups
4. **Scalable:** Can handle 10x growth without hardware changes
5. **Offline-capable:** Works at cabin without internet
6. **Extensible:** Easy to add new integrations and agents

**Trade-offs:**
- Not cloud-hosted (must maintain own infrastructure)
- Requires VPN setup for remote access
- Single-user focused (would need rewrite for multi-tenant SaaS)

### Next Steps

1. **Set up Raspberry Pi 5** with SSD and LifeOps stack
2. **Implement core services** (API, Orchestrator, Sync)
3. **Build Phase 1 agents** (Sleep, Work-Life, Screen Time)
4. **Deploy to cabins** (Linux PCs with same Docker Compose)
5. **Develop mobile apps** (iOS first, using REST + WebSocket API)

### Success Criteria

- [ ] Pi runs for 30 days without intervention (stable)
- [ ] Oura data syncs every 5 minutes reliably
- [ ] Cabin sync completes in <5 minutes (acceptable)
- [ ] Mobile app responds in <100ms on local network (fast)
- [ ] Sleep Agent triggers wind-down mode correctly (functional)
- [ ] Total cost <$200 (budget-friendly)
- [ ] Power consumption <10W average (efficient)

---

**This architecture provides a solid, privacy-first, efficient foundation for LifeOps that will scale with the user's needs while respecting the core values of self-hosting and data ownership.**

**Version:** 1.0
**Date:** 2026-01-08
**Status:** Recommended for Implementation
