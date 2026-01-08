# LifeOps Setup Guide

Step-by-step instructions for setting up the LifeOps system on Arch Linux.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Directory Structure](#directory-structure)
3. [Docker Setup](#docker-setup)
4. [Home Assistant](#home-assistant)
5. [ESPHome](#esphome)
6. [TimescaleDB](#timescaledb)
7. [MQTT (Mosquitto)](#mqtt-mosquitto)
8. [Zigbee2MQTT](#zigbee2mqtt-optional)
9. [LifeOps API](#lifeops-api)
10. [LifeOps Web](#lifeops-web)
11. [Tailscale VPN](#tailscale-vpn)
12. [Plejd Integration](#plejd-integration)
13. [Sensor Setup](#sensor-setup)
14. [Verification](#verification)
15. [Maintenance](#maintenance)

---

## Prerequisites

### System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 8 GB | 16+ GB |
| Storage | 50 GB | 100+ GB SSD |
| OS | Arch Linux | Arch Linux |
| Network | Ethernet | Ethernet |

### Required Packages

```bash
# Update system
sudo pacman -Syu

# Install Docker
sudo pacman -S docker docker-compose

# Enable and start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Add user to docker group (logout/login after)
sudo usermod -aG docker $USER

# Install git for version control
sudo pacman -S git

# Install esptool for flashing ESP32 (optional, ESPHome handles this)
sudo pacman -S esptool
```

### USB Device Permissions

For Zigbee USB dongle:

```bash
# Create udev rule for Zigbee dongle
sudo tee /etc/udev/rules.d/99-zigbee.rules << 'EOF'
SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", SYMLINK+="zigbee", MODE="0666"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

---

## Directory Structure

Create the LifeOps directory structure:

```bash
# Create main directory
mkdir -p ~/lifeops
cd ~/lifeops

# Create subdirectories
mkdir -p homeassistant
mkdir -p esphome
mkdir -p zigbee2mqtt
mkdir -p mosquitto/config
mkdir -p timescaledb
mkdir -p services/api
mkdir -p apps/web

# Create environment file
touch .env
```

### Directory Layout

```
~/lifeops/
├── docker-compose.yml
├── .env
├── homeassistant/
│   └── configuration.yaml
├── esphome/
│   ├── secrets.yaml
│   └── [sensor configs].yaml
├── zigbee2mqtt/
│   └── configuration.yaml
├── mosquitto/
│   └── config/
│       └── mosquitto.conf
├── timescaledb/
│   └── [data files]
├── services/
│   └── api/
│       ├── Dockerfile
│       └── [API code]
└── apps/
    └── web/
        ├── Dockerfile
        └── [Web code]
```

---

## Docker Setup

### Environment File

Create `~/lifeops/.env`:

```bash
# Database
DB_PASSWORD=your_secure_password_here

# Oura API
OURA_TOKEN=your_oura_personal_access_token

# JWT Secret
JWT_SECRET=your_jwt_secret_here

# ESPHome
ESPHOME_DASHBOARD_USE_PING=true
```

### Docker Compose File

Create `~/lifeops/docker-compose.yml`:

```yaml
version: '3.8'

services:
  homeassistant:
    image: ghcr.io/home-assistant/home-assistant:stable
    container_name: homeassistant
    volumes:
      - ./homeassistant:/config
      - /run/dbus:/run/dbus:ro
    devices:
      - /dev/zigbee:/dev/ttyUSB0
    network_mode: host
    restart: unless-stopped
    depends_on:
      - mosquitto

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    volumes:
      - ./esphome:/config
    network_mode: host
    restart: unless-stopped

  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto/config:/mosquitto/config
      - ./mosquitto/data:/mosquitto/data
      - ./mosquitto/log:/mosquitto/log
    restart: unless-stopped

  timescaledb:
    image: timescale/timescaledb:latest-pg15
    container_name: timescaledb
    environment:
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: lifeops
    volumes:
      - ./timescaledb:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    restart: unless-stopped

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    volumes:
      - ./zigbee2mqtt:/app/data
    devices:
      - /dev/zigbee:/dev/ttyUSB0
    depends_on:
      - mosquitto
    restart: unless-stopped
    profiles:
      - zigbee

  lifeops-api:
    build: ./services/api
    container_name: lifeops-api
    environment:
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD}@timescaledb:5432/lifeops
      MQTT_BROKER: localhost
      OURA_TOKEN: ${OURA_TOKEN}
      JWT_SECRET: ${JWT_SECRET}
    ports:
      - "8000:8000"
    depends_on:
      - timescaledb
      - mosquitto
    restart: unless-stopped
    profiles:
      - lifeops

  lifeops-web:
    build: ./apps/web
    container_name: lifeops-web
    ports:
      - "3000:3000"
    depends_on:
      - lifeops-api
    restart: unless-stopped
    profiles:
      - lifeops
```

### Start Core Services

```bash
cd ~/lifeops

# Start core services (HA, ESPHome, MQTT, TimescaleDB)
docker compose up -d homeassistant esphome mosquitto timescaledb

# Check status
docker compose ps

# View logs
docker compose logs -f
```

---

## Home Assistant

### Initial Setup

1. Access Home Assistant at `http://localhost:8123`
2. Create admin account
3. Complete onboarding wizard

### Configuration File

Create `~/lifeops/homeassistant/configuration.yaml`:

```yaml
# Home Assistant Configuration

homeassistant:
  name: LifeOps Home
  unit_system: metric
  time_zone: Europe/Oslo
  currency: NOK

# Enable default integrations
default_config:

# HTTP configuration
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 127.0.0.1
    - 100.64.0.0/10  # Tailscale

# MQTT
mqtt:
  broker: localhost
  port: 1883

# Recorder for history
recorder:
  purge_keep_days: 30
  db_url: postgresql://postgres:${DB_PASSWORD}@localhost:5432/homeassistant

# Logger
logger:
  default: info
  logs:
    homeassistant.components.plejd: debug

# Automations
automation: !include automations.yaml

# Scripts
script: !include scripts.yaml

# Scenes
scene: !include scenes.yaml

# REST commands for LifeOps API
rest_command:
  log_sleep_environment:
    url: "http://localhost:8000/api/sleep-environment"
    method: POST
    content_type: "application/json"
    payload: '{"temperature": {{ temperature }}, "humidity": {{ humidity }}}'
```

### Create Empty Include Files

```bash
touch ~/lifeops/homeassistant/automations.yaml
touch ~/lifeops/homeassistant/scripts.yaml
touch ~/lifeops/homeassistant/scenes.yaml
```

### Restart Home Assistant

```bash
docker restart homeassistant
```

---

## ESPHome

### Secrets File

Create `~/lifeops/esphome/secrets.yaml`:

```yaml
# WiFi credentials
wifi_ssid: "YourWiFiSSID"
wifi_password: "YourWiFiPassword"

# API encryption key (generate with: openssl rand -base64 32)
api_encryption_key: "your_32_byte_base64_key_here"

# OTA password
ota_password: "your_ota_password"

# Fallback AP password
fallback_ap_password: "fallback_password"
```

### Access ESPHome Dashboard

ESPHome dashboard available at `http://localhost:6052`

### First Sensor Configuration

See `esphome/` directory for sensor configuration files. Create from templates in ARCHITECTURE.md or use the ESPHome dashboard wizard.

---

## TimescaleDB

### Initialize Database

Connect to TimescaleDB and create schema:

```bash
# Connect to database
docker exec -it timescaledb psql -U postgres -d lifeops
```

Run the schema creation:

```sql
-- Create hypertables for time-series data

-- Health metrics (Oura)
CREATE TABLE IF NOT EXISTS health_metrics (
    time        TIMESTAMPTZ NOT NULL,
    metric_type TEXT NOT NULL,
    value       DOUBLE PRECISION,
    metadata    JSONB
);
SELECT create_hypertable('health_metrics', 'time', if_not_exists => TRUE);

-- Sensor readings
CREATE TABLE IF NOT EXISTS sensor_readings (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   TEXT NOT NULL,
    metric      TEXT NOT NULL,
    value       DOUBLE PRECISION
);
SELECT create_hypertable('sensor_readings', 'time', if_not_exists => TRUE);

-- Habit logs
CREATE TABLE IF NOT EXISTS habit_logs (
    time        TIMESTAMPTZ NOT NULL,
    habit_id    TEXT NOT NULL,
    completed   BOOLEAN,
    value       DOUBLE PRECISION,
    notes       TEXT
);
SELECT create_hypertable('habit_logs', 'time', if_not_exists => TRUE);

-- Gamification events
CREATE TABLE IF NOT EXISTS gamification_events (
    time        TIMESTAMPTZ NOT NULL,
    event_type  TEXT NOT NULL,
    xp_earned   INTEGER,
    details     JSONB
);
SELECT create_hypertable('gamification_events', 'time', if_not_exists => TRUE);

-- Configuration tables
CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    settings    JSONB,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS streaks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    streak_type TEXT NOT NULL,
    current     INTEGER DEFAULT 0,
    best        INTEGER DEFAULT 0,
    last_date   DATE,
    freeze_tokens INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS achievements (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        TEXT UNIQUE NOT NULL,
    unlocked_at TIMESTAMPTZ,
    progress    INTEGER DEFAULT 0
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_health_metrics_type ON health_metrics (metric_type, time DESC);
CREATE INDEX IF NOT EXISTS idx_sensor_readings_sensor ON sensor_readings (sensor_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_habit_logs_habit ON habit_logs (habit_id, time DESC);

-- Compression policy (compress data older than 7 days)
SELECT add_compression_policy('health_metrics', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_compression_policy('sensor_readings', INTERVAL '7 days', if_not_exists => TRUE);

-- Retention policy (keep raw data for 30 days, aggregated forever)
-- Note: Add continuous aggregates for long-term storage

\q
```

---

## MQTT (Mosquitto)

### Configuration File

Create `~/lifeops/mosquitto/config/mosquitto.conf`:

```conf
# Mosquitto Configuration

# Listener
listener 1883

# Allow anonymous for local services
allow_anonymous true

# Persistence
persistence true
persistence_location /mosquitto/data/

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_type all
```

### Restart Mosquitto

```bash
docker restart mosquitto
```

### Test MQTT

```bash
# Install mosquitto-clients on host
sudo pacman -S mosquitto

# Subscribe to all topics
mosquitto_sub -h localhost -t '#' -v

# In another terminal, publish test message
mosquitto_pub -h localhost -t 'test/topic' -m 'Hello LifeOps'
```

---

## Zigbee2MQTT (Optional)

Only needed when adding Zigbee devices.

### Configuration

Create `~/lifeops/zigbee2mqtt/configuration.yaml`:

```yaml
# Zigbee2MQTT Configuration

homeassistant: true

permit_join: false

mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://localhost

serial:
  port: /dev/ttyUSB0

frontend:
  port: 8080

advanced:
  log_level: info
  network_key: GENERATE
  pan_id: GENERATE
```

### Start Zigbee2MQTT

```bash
# Start with zigbee profile
docker compose --profile zigbee up -d
```

### Access Frontend

Zigbee2MQTT frontend at `http://localhost:8080`

---

## LifeOps API

### Create API Project

```bash
cd ~/lifeops/services/api

# Initialize Python project
python -m venv venv
source venv/bin/activate

# Create requirements.txt
cat > requirements.txt << 'EOF'
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.3
sqlalchemy==2.0.25
asyncpg==0.29.0
psycopg2-binary==2.9.9
paho-mqtt==1.6.1
httpx==0.26.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-multipart==0.0.6
EOF

# Install dependencies
pip install -r requirements.txt
```

### Create Dockerfile

Create `~/lifeops/services/api/Dockerfile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Create Main API File

Create `~/lifeops/services/api/main.py`:

```python
"""LifeOps API - Main entry point"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="LifeOps API",
    description="Personal life management system API",
    version="0.1.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure properly in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"status": "ok", "service": "LifeOps API"}

@app.get("/api/health")
async def health():
    return {"status": "healthy"}

@app.get("/api/today")
async def get_today():
    """Get today's scores - main endpoint for mobile app"""
    # TODO: Implement actual score calculation
    return {
        "life_score": 75,
        "domains": {
            "sleep": 80,
            "activity": 70,
            "work_life": 75,
            "habits": 72
        },
        "xp": {
            "today": 750,
            "total": 12500,
            "level": 4
        },
        "streaks": {
            "morning_victory": 5,
            "gym_chain": 2
        }
    }
```

### Build and Start API

```bash
# Start with lifeops profile
docker compose --profile lifeops up -d lifeops-api
```

---

## LifeOps Web

### Create Web Project

```bash
cd ~/lifeops/apps/web

# Initialize Next.js project (requires Node.js)
npx create-next-app@latest . --typescript --tailwind --app
```

### Create Dockerfile

Create `~/lifeops/apps/web/Dockerfile`:

```dockerfile
FROM node:20-alpine AS base

FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV production

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

EXPOSE 3000
CMD ["node", "server.js"]
```

### Build and Start Web

```bash
# Start with lifeops profile
docker compose --profile lifeops up -d lifeops-web
```

---

## Tailscale VPN

### Install Tailscale

```bash
# Install from AUR or official repo
sudo pacman -S tailscale

# Enable and start
sudo systemctl enable tailscaled
sudo systemctl start tailscaled

# Authenticate
sudo tailscale up
```

### Configure Tailscale

1. Log in to Tailscale admin console
2. Enable MagicDNS
3. Configure ACLs for LifeOps services

### Access from Remote

Once connected to Tailscale, access services via Tailscale IP or MagicDNS hostname:
- Home Assistant: `http://lifeops-hub:8123`
- ESPHome: `http://lifeops-hub:6052`
- LifeOps API: `http://lifeops-hub:8000`
- LifeOps Web: `http://lifeops-hub:3000`

---

## Plejd Integration

### Prerequisites

- Plejd Gateway (GWY-01) installed and connected to network
- Plejd devices commissioned via Plejd app

### Home Assistant Integration

1. Go to Settings → Devices & Services
2. Add Integration → Search "Plejd"
3. Enter gateway IP address
4. Enter crypto key (from Plejd app settings)

### Get Crypto Key

In Plejd app:
1. Settings → About
2. Tap "Copy Plejd local API key"
3. Paste into Home Assistant

### Verify Integration

After adding:
- All Plejd lights should appear as entities
- Test on/off and dimming from HA
- Create scenes and automations

---

## Sensor Setup

### Flash ESPHome Firmware

1. Connect ESP32-C3 via USB
2. In ESPHome dashboard, create new device
3. Choose ESP32-C3 board
4. Configure WiFi and API key
5. Click "Install" → "Plug into computer"

### First-Time Flash

```bash
# If ESPHome dashboard fails, use esptool directly
esptool.py --chip esp32c3 --port /dev/ttyUSB0 erase_flash
esptool.py --chip esp32c3 --port /dev/ttyUSB0 write_flash 0x0 firmware.bin
```

### OTA Updates

After first flash, updates happen over WiFi:
- Edit configuration in ESPHome dashboard
- Click "Install" → "Wirelessly"

### Verify in Home Assistant

1. Go to Settings → Devices & Services
2. ESPHome integration should auto-discover new devices
3. Click "Configure" to add device
4. Entities appear in Home Assistant

---

## Verification

### Service Health Checklist

| Service | URL | Expected |
|---------|-----|----------|
| Home Assistant | http://localhost:8123 | Dashboard |
| ESPHome | http://localhost:6052 | Dashboard |
| MQTT | localhost:1883 | Connection accepted |
| TimescaleDB | localhost:5432 | Connection accepted |
| LifeOps API | http://localhost:8000 | {"status": "ok"} |
| LifeOps Web | http://localhost:3000 | Dashboard |

### Test Commands

```bash
# Check all containers
docker compose ps

# Check logs for errors
docker compose logs homeassistant | grep -i error
docker compose logs esphome | grep -i error

# Test MQTT
mosquitto_pub -h localhost -t 'lifeops/test' -m 'ping'

# Test database
docker exec -it timescaledb psql -U postgres -d lifeops -c "SELECT COUNT(*) FROM health_metrics;"

# Test API
curl http://localhost:8000/api/health
curl http://localhost:8000/api/today
```

---

## Maintenance

### Backup Strategy

```bash
# Create backup script
cat > ~/lifeops/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/backup/lifeops/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Stop services
cd ~/lifeops
docker compose stop

# Backup volumes
tar -czf "$BACKUP_DIR/homeassistant.tar.gz" homeassistant/
tar -czf "$BACKUP_DIR/esphome.tar.gz" esphome/
tar -czf "$BACKUP_DIR/zigbee2mqtt.tar.gz" zigbee2mqtt/
tar -czf "$BACKUP_DIR/mosquitto.tar.gz" mosquitto/

# Backup database
docker exec timescaledb pg_dump -U postgres lifeops | gzip > "$BACKUP_DIR/lifeops.sql.gz"

# Restart services
docker compose start

echo "Backup complete: $BACKUP_DIR"
EOF

chmod +x ~/lifeops/backup.sh
```

### Update Services

```bash
cd ~/lifeops

# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Clean old images
docker image prune -f
```

### Monitor Resources

```bash
# Check container stats
docker stats

# Check disk usage
docker system df

# Check logs size
du -sh ~/lifeops/*/
```

### Common Issues

| Issue | Solution |
|-------|----------|
| Container won't start | Check logs: `docker compose logs [service]` |
| Database connection failed | Verify password in .env matches |
| Zigbee device not found | Check USB symlink: `ls -la /dev/zigbee` |
| ESPHome can't connect | Verify WiFi credentials in secrets.yaml |
| Home Assistant slow | Check recorder settings, reduce history |

---

## Next Steps

After completing setup:

1. **Add ESPHome sensors** - Flash and configure DIY sensors
2. **Create automations** - Motion lights, wake routines
3. **Integrate Plejd** - After gateway installation
4. **Build LifeOps API** - Implement gamification logic
5. **Deploy mobile app** - iOS development

See ARCHITECTURE.md for full system design and implementation phases.

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-01 | 1.0 | Initial setup documentation |

---

*Reference ARCHITECTURE.md for system design and HARDWARE.md for component specifications.*
