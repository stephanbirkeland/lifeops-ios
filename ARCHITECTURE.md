# LifeOps Architecture

This document defines the complete technical architecture for LifeOps - a unified personal life management system.

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Design Principles](#design-principles)
3. [Hardware Architecture](#hardware-architecture)
4. [Software Stack](#software-stack)
5. [Data Architecture](#data-architecture)
6. [Integration Layer](#integration-layer)
7. [Gamification System](#gamification-system)
8. [Security Architecture](#security-architecture)
9. [Client Applications](#client-applications)
10. [Implementation Phases](#implementation-phases)
11. [Shopping List](#shopping-list)

---

## System Overview

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         LifeOps Architecture                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────┐     │
│  │              Arch Linux Desktop (Main Hub)                  │     │
│  │                      32GB RAM                               │     │
│  ├────────────────────────────────────────────────────────────┤     │
│  │                                                             │     │
│  │  ┌─────────────────┐     ┌─────────────────┐              │     │
│  │  │  Home Assistant │     │ LifeOps Services│              │     │
│  │  │    (Docker)     │────▶│   (FastAPI)     │              │     │
│  │  ├─────────────────┤     ├─────────────────┤              │     │
│  │  │ • Plejd Gateway │     │ • Gamification  │              │     │
│  │  │ • Zigbee (Z2M)  │     │ • Habit Tracker │              │     │
│  │  │ • SmartThings   │     │ • Agent System  │              │     │
│  │  │ • HomeKit       │     │ • Oura Sync     │              │     │
│  │  │ • Google Cast   │     │ • Calendar Sync │              │     │
│  │  └─────────────────┘     └─────────────────┘              │     │
│  │           │                       │                        │     │
│  │           └───────────┬───────────┘                        │     │
│  │                       ▼                                    │     │
│  │  ┌─────────────────────────────────────┐                  │     │
│  │  │        MQTT + TimescaleDB           │                  │     │
│  │  │     (Event Bus + Time-Series)       │                  │     │
│  │  └─────────────────────────────────────┘                  │     │
│  │                                                            │     │
│  └────────────────────────────────────────────────────────────┘     │
│                              │                                       │
│                       [Tailscale VPN]                                │
│           ┌──────────────────┼──────────────────┐                   │
│           ▼                  ▼                  ▼                    │
│     ┌──────────┐       ┌──────────┐       ┌──────────┐              │
│     │  Summer  │       │  Winter  │       │  Clients │              │
│     │  Cabin   │       │  Cabin   │       │          │              │
│     │  (Pi 4)  │       │  (Pi 4)  │       │ • iPhone │              │
│     │          │       │          │       │ • Web    │              │
│     └──────────┘       └──────────┘       │ • Linux  │              │
│       Phase 2            Phase 3          └──────────┘              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

Device Layer:
├─ Plejd Lighting (via Plejd Gateway → WiFi)
├─ Zigbee Sensors (via USB Dongle → Zigbee2MQTT)
├─ Samsung TVs/Speakers (via SmartThings API)
├─ HomePod (via HomeKit)
├─ Google Bathroom Speaker (via Cast)
└─ Oura Ring (via REST API)
```

### Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Main Hub | Existing Arch Linux desktop | 32GB RAM, always-on, no additional cost |
| Smart Home Platform | Home Assistant (Docker) | 2000+ integrations, self-hosted, mature |
| Sensor Protocol | Zigbee | Low power, mesh network, local control |
| Plejd Integration | Plejd Gateway | Network-based, reliable, no Bluetooth needed |
| Database | SQLite + TimescaleDB | Config + time-series health data |
| Remote Access | Tailscale | WireGuard VPN, zero config, secure |
| Mobile App | Native Swift (iOS) | Lightweight, fetches only needed data |
| Web Dashboard | Next.js | Full analytics, keyboard shortcuts |

---

## Design Principles

### 1. Hub-Centric Architecture

All intelligence lives on the hub. Clients are thin and lightweight.

```
Hub responsibilities:
├─ All data processing and analytics
├─ Oura API polling and correlation
├─ Gamification calculations
├─ Automation execution
└─ Large dataset storage

Client responsibilities:
├─ Display current scores
├─ Send user actions
├─ Receive push notifications
└─ Minimal local caching
```

### 2. Lightweight Data Transfer

Each client fetches only what it needs.

| Endpoint | Payload | Use Case |
|----------|---------|----------|
| `GET /api/today` | ~500 bytes | Daily scores, streaks, next action |
| `GET /api/quick-actions` | ~200 bytes | Available scene buttons |
| `POST /api/action/{id}` | ~50 bytes | Trigger scene/device |
| `WS /api/events` | Push only | Real-time updates (scores, alerts) |
| `GET /api/analytics/*` | Variable | Web dashboard only (full data) |

### 3. Privacy First

- All data stored locally on hub
- No cloud dependencies for core functionality
- Third-party APIs (Oura, calendars) polled and stored locally
- Tailscale for secure remote access (no port forwarding)

### 4. Offline Capable

- Hub operates independently
- Local automations work without internet
- Cabin hubs sync when connected
- Mobile app caches essential data

### 5. Fast & Secure Communication

- TLS 1.3 for all connections
- mTLS for device authentication
- <100ms latency for local device control
- <500ms for Plejd lighting commands

---

## Hardware Architecture

### Phase 1: Home (Current)

| Component | Hardware | Purpose |
|-----------|----------|---------|
| Main Hub | Arch Linux Desktop (32GB RAM) | All processing, storage, services |
| Zigbee Coordinator | Sonoff Zigbee 3.0 USB Dongle | Future Zigbee devices if needed |
| Plejd Bridge | Plejd Gateway | Lighting control via network |
| Sensors | DIY ESP32-C3 + ESPHome | Motion, temp, door, buttons |

### Current Plejd Setup

| Location | Device | Type |
|----------|--------|------|
| Bedroom | Inline dimmer on corner lamp | DIM-01/02 |

### Planned Plejd Expansion (Kitchen Renovation)

| Location | Device | Purpose |
|----------|--------|---------|
| Living room | DIM-01 ×2 | Ceiling lights (dimmable) |
| Kitchen | DIM-02 or LED-10 | Cabinet lighting |
| Bathroom | CTL-01 ×2 | Ceiling + mirror (on/off) |
| Entrance | CTL-01 | Ceiling (on/off) |
| Bedroom | DIM-01 | Ceiling (dimmable) |
| All | GWY-01 | Gateway for network control |

### Phase 2-3: Cabins (Future)

| Location | Hardware | Purpose |
|----------|----------|---------|
| Summer Cabin | Raspberry Pi 4 (4GB) | Local hub, syncs to main |
| Winter Cabin | Raspberry Pi 4 (4GB) | Local hub, syncs to main |

### DIY Sensor Specifications

**Platform**: ESP32-C3 Super Mini (22×18mm, WiFi, BLE, deep sleep capable)

**Firmware**: ESPHome (native Home Assistant integration, OTA updates)

| Sensor Type | Components | Size | Power | Use Case |
|-------------|------------|------|-------|----------|
| **Multi-sensor** | ESP32-C3 + BME280 + AM312 | ~30×25×15mm | LiPo 500mAh | Room monitoring (motion + temp + humidity) |
| **Door sensor** | ESP32-C3 + Reed switch | ~25×18×10mm | CR2032 | Entry detection |
| **Button** | ESP32-C3 + Tactile switch | ~25×18×8mm | CR2032 | Manual scene trigger |

### Sensor Placement (Home)

| Room | Sensor Type | Components | Automation Use |
|------|-------------|------------|----------------|
| **Bedroom** | Multi-sensor | ESP32-C3 + BME280 + AM312 | Wake detection, sleep environment |
| **Bedroom** | Button | ESP32-C3 + tactile | Bedside scene control |
| **Living Room** | Multi-sensor | ESP32-C3 + BME280 + AM312 | Presence, comfort monitoring |
| **Bathroom** | Multi-sensor | ESP32-C3 + BME280 + AM312 | Auto-lights, humidity tracking |
| **Entry** | Door sensor | ESP32-C3 + Reed switch | Arrival/departure detection |
| **Entry** | Multi-sensor | ESP32-C3 + BME280 + AM312 | Motion for hallway lights |

---

## Software Stack

### Docker Compose Services

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
      - /dev/ttyUSB0:/dev/ttyUSB0  # Zigbee dongle
    network_mode: host
    restart: unless-stopped

  esphome:
    image: ghcr.io/esphome/esphome
    container_name: esphome
    volumes:
      - ./esphome:/config
    network_mode: host
    restart: unless-stopped

  zigbee2mqtt:
    image: koenkk/zigbee2mqtt
    container_name: zigbee2mqtt
    volumes:
      - ./zigbee2mqtt:/app/data
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
    depends_on:
      - mosquitto
    restart: unless-stopped
    profiles:
      - zigbee  # Only start when zigbee profile is enabled

  mosquitto:
    image: eclipse-mosquitto:2
    container_name: mosquitto
    ports:
      - "1883:1883"
    volumes:
      - ./mosquitto:/mosquitto/config
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

  lifeops-api:
    build: ./services/api
    container_name: lifeops-api
    environment:
      DATABASE_URL: postgresql://postgres:${DB_PASSWORD}@timescaledb:5432/lifeops
      MQTT_BROKER: mosquitto
      OURA_TOKEN: ${OURA_TOKEN}
    ports:
      - "8000:8000"
    depends_on:
      - timescaledb
      - mosquitto
    restart: unless-stopped

  lifeops-web:
    build: ./apps/web
    container_name: lifeops-web
    ports:
      - "3000:3000"
    depends_on:
      - lifeops-api
    restart: unless-stopped
```

### Technology Choices

| Layer | Technology | Why |
|-------|------------|-----|
| **Container Runtime** | Docker + Docker Compose | Standard, easy management |
| **Smart Home** | Home Assistant | Best integration ecosystem |
| **Zigbee** | Zigbee2MQTT | More flexible than HA Zigbee |
| **Message Bus** | Mosquitto (MQTT) | Lightweight, standard IoT protocol |
| **Database** | TimescaleDB (PostgreSQL) | Time-series optimized, SQL |
| **API Framework** | FastAPI (Python) | Async, fast, auto-docs |
| **Web Framework** | Next.js | React, SSR, good DX |

---

## Data Architecture

### Database Schema

```sql
-- TimescaleDB Hypertables for time-series data

-- Oura health metrics
CREATE TABLE health_metrics (
    time        TIMESTAMPTZ NOT NULL,
    metric_type TEXT NOT NULL,
    value       DOUBLE PRECISION,
    metadata    JSONB
);
SELECT create_hypertable('health_metrics', 'time');

-- Sensor readings
CREATE TABLE sensor_readings (
    time        TIMESTAMPTZ NOT NULL,
    sensor_id   TEXT NOT NULL,
    metric      TEXT NOT NULL,
    value       DOUBLE PRECISION
);
SELECT create_hypertable('sensor_readings', 'time');

-- Habit logs
CREATE TABLE habit_logs (
    time        TIMESTAMPTZ NOT NULL,
    habit_id    TEXT NOT NULL,
    completed   BOOLEAN,
    value       DOUBLE PRECISION,
    notes       TEXT
);
SELECT create_hypertable('habit_logs', 'time');

-- Gamification events
CREATE TABLE gamification_events (
    time        TIMESTAMPTZ NOT NULL,
    event_type  TEXT NOT NULL,
    xp_earned   INTEGER,
    details     JSONB
);
SELECT create_hypertable('gamification_events', 'time');

-- Regular tables for configuration
CREATE TABLE users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    settings    JSONB,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE streaks (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    streak_type TEXT NOT NULL,
    current     INTEGER DEFAULT 0,
    best        INTEGER DEFAULT 0,
    last_date   DATE,
    freeze_tokens INTEGER DEFAULT 0
);

CREATE TABLE achievements (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code        TEXT UNIQUE NOT NULL,
    unlocked_at TIMESTAMPTZ,
    progress    INTEGER DEFAULT 0
);
```

### Data Retention

| Data Type | Retention | Aggregation |
|-----------|-----------|-------------|
| Raw sensor readings | 30 days | Hourly averages kept forever |
| Oura daily metrics | Forever | Already daily granularity |
| Habit logs | Forever | Small data volume |
| Gamification events | Forever | Small data volume |

### Data Flow

```
External APIs                    Sensors                    User Actions
     │                              │                            │
     ▼                              ▼                            ▼
┌─────────────┐            ┌─────────────┐              ┌─────────────┐
│ Oura Sync   │            │ Zigbee2MQTT │              │ LifeOps API │
│ (hourly)    │            │             │              │             │
└──────┬──────┘            └──────┬──────┘              └──────┬──────┘
       │                          │                            │
       │         MQTT             │           MQTT             │
       └────────────┬─────────────┴─────────────┬──────────────┘
                    │                           │
                    ▼                           ▼
            ┌─────────────┐             ┌─────────────┐
            │ TimescaleDB │             │    Home     │
            │             │◀───────────▶│  Assistant  │
            └──────┬──────┘             └─────────────┘
                   │
                   ▼
            ┌─────────────┐
            │ Gamification│
            │   Engine    │
            └──────┬──────┘
                   │
                   ▼
            ┌─────────────┐
            │   Clients   │
            │ (API calls) │
            └─────────────┘
```

---

## Integration Layer

### Plejd (Lighting)

**Method**: Plejd Gateway → Local Network → Home Assistant

```yaml
# Home Assistant configuration.yaml
plejd:
  crypto_key: !secret plejd_crypto_key
```

**Capabilities**:
- On/off control
- Dimming
- Color temperature (if supported)
- Scenes

**Latency**: 200-400ms

### ESPHome Sensors (Primary)

**Method**: ESP32-C3 → WiFi → ESPHome API → Home Assistant

**Architecture**:
```
ESP32-C3 Sensor
    │
    │ WiFi (encrypted)
    ▼
Home Assistant
    │
    │ ESPHome API (native integration)
    ▼
LifeOps Services
```

**Advantages**:
- Native Home Assistant integration
- OTA firmware updates
- Deep sleep for battery life
- Fully customizable
- Smallest possible form factor

**Latency**: 50-150ms

### Zigbee (Reserved for Future)

**Method**: USB Dongle → Zigbee2MQTT → MQTT → Home Assistant

**Status**: Zigbee dongle purchased for future expansion or commercial devices if needed.

**Latency**: 50-200ms

### Oura Ring

**Method**: REST API polling → TimescaleDB

```python
# Polling schedule
OURA_SYNC_SCHEDULE = {
    "daily_sleep": "09:00",      # After ring syncs overnight
    "daily_readiness": "09:00",  # Calculated by Oura overnight
    "daily_activity": "hourly",  # During waking hours
    "heart_rate": "30min",       # For HRV trends
}
```

**Data Points**:
- Sleep score, duration, stages, efficiency
- Readiness score
- Activity score, steps, calories
- HRV (heart rate variability)
- Body temperature deviation

### Calendars

**Method**: CalDAV polling → Local cache

| Service | Protocol | Sync Frequency |
|---------|----------|----------------|
| Google Calendar | CalDAV / Google API | 15 minutes |
| Apple Calendar | CalDAV | 15 minutes |
| Outlook | Microsoft Graph API | 15 minutes |

### Samsung SmartThings

**Method**: SmartThings Cloud API → Home Assistant

**Devices**:
- Living room TV
- Bedroom TV
- Living room speakers
- Bedroom speakers

**Capabilities**:
- Power on/off
- Volume control
- Source selection

### Google Cast (Bathroom Speaker)

**Method**: Local Cast protocol → Home Assistant

**Capabilities**:
- Play/pause/stop
- Volume control
- Cast audio (Spotify, TTS)

### HomeKit (HomePod)

**Method**: HomeKit Controller → Home Assistant

**Capabilities**:
- Siri voice control (independent)
- HomeKit scenes
- Media playback

---

## Gamification System

### Life Score Calculation

```
Life Score = (Sleep × 0.40) + (Activity × 0.25) + (Work-Life × 0.20) + (Habits × 0.15)
```

### Domain Scores

#### Sleep Score (40% weight)

```python
def calculate_sleep_score(oura_data, schedule_data, routine_data):
    # Oura sleep score (0-100) - 60% weight
    oura_component = oura_data.sleep_score * 0.60

    # Schedule consistency - 25% weight
    # 100 - (minutes deviation from target wake / 2)
    wake_deviation = abs(schedule_data.actual_wake - schedule_data.target_wake)
    schedule_component = max(0, 100 - (wake_deviation.minutes / 2)) * 0.25

    # Pre-bed routine - 15% weight
    routine_score = 0
    if routine_data.screens_off_30min: routine_score += 50
    if routine_data.lights_dimmed: routine_score += 30
    if routine_data.in_bed_on_time: routine_score += 20
    routine_component = routine_score * 0.15

    return oura_component + schedule_component + routine_component
```

#### Activity Score (25% weight)

```python
def calculate_activity_score(oura_data, gym_data, steps_data):
    # Oura activity score - 40% weight
    oura_component = oura_data.activity_score * 0.40

    # Gym sessions (rolling 7 days) - 40% weight
    sessions = gym_data.sessions_last_7_days
    gym_component = min(100, (sessions / 3) * 100) * 0.40

    # Daily steps - 20% weight
    steps = steps_data.today
    if steps >= 10000: steps_score = 100
    elif steps >= 7000: steps_score = 90
    elif steps >= 5000: steps_score = 70
    elif steps >= 3000: steps_score = 40
    else: steps_score = 0
    steps_component = steps_score * 0.20

    return oura_component + gym_component + steps_component
```

#### Work-Life Score (20% weight)

```python
def calculate_worklife_score(work_data, weekend_data):
    # Work hours - 40% weight
    hours = work_data.hours_today
    if hours <= 8: hours_score = 100
    elif hours <= 9: hours_score = 85
    elif hours <= 10: hours_score = 60
    elif hours <= 11: hours_score = 30
    else: hours_score = 0
    hours_component = hours_score * 0.40

    # Work cutoff time - 35% weight
    cutoff = work_data.last_activity_time
    if cutoff.hour < 17: cutoff_score = 100
    elif cutoff.hour < 18: cutoff_score = 100
    elif cutoff.hour < 19: cutoff_score = 80
    elif cutoff.hour < 20: cutoff_score = 50
    elif cutoff.hour < 21: cutoff_score = 20
    else: cutoff_score = 0
    cutoff_component = cutoff_score * 0.35

    # Weekend recovery - 25% weight
    weekend_work = weekend_data.hours_worked
    if weekend_work == 0: weekend_score = 100
    elif weekend_work < 2: weekend_score = 70
    elif weekend_work < 4: weekend_score = 40
    else: weekend_score = 0
    weekend_component = weekend_score * 0.25

    return hours_component + cutoff_component + weekend_component
```

#### Habits Score (15% weight)

```python
def calculate_habits_score(screen_data, checklist_data):
    # Screen time - 50% weight
    hours = screen_data.phone_hours_today
    if hours < 2: screen_score = 100
    elif hours < 3: screen_score = 80
    elif hours < 4: screen_score = 60
    elif hours < 5: screen_score = 30
    else: screen_score = 0
    screen_component = screen_score * 0.50

    # Daily checklist - 50% weight
    completed = checklist_data.completed_count
    total = checklist_data.total_count
    checklist_component = (completed / total * 100) * 0.50

    return screen_component + checklist_component
```

### XP System

```python
# Daily XP
daily_xp = life_score * 10  # 500-1000 XP per day

# Bonus XP
BONUS_XP = {
    "perfect_sleep_score": 200,
    "gym_session": 150,
    "early_work_cutoff": 100,
    "all_habits_complete": 150,
    "life_score_90_plus": 300,
    "life_score_95_plus": 500,
    "10k_steps": 100,
    "sub_2hr_screen": 200,
}

# Level calculation
def xp_for_level(level):
    return 1000 * level * level  # 1000, 4000, 9000, 16000...
```

### Streaks

| Streak | Trigger | Grace Mechanic |
|--------|---------|----------------|
| Morning Victory | Wake ≤6:00 + routine by 7:00 | 1 sleep-in token per 14 days |
| Gym Chain | 3+ sessions/week | 2 rest week passes per year |
| Work-Life Boundary | Cutoff <7pm + <9hr work | 2 crunch exceptions per month |
| Screen Mastery | <3hr screen time | 1 binge day per week |

### Achievements

| Tier | Examples | XP Reward |
|------|----------|-----------|
| Bronze | First 70+ Life Score, First gym session | 200 |
| Silver | 7-day wake streak, 4 weeks gym | 500 |
| Gold | 30-day Life Score 80+, 60-day wake streak | 1,500 |
| Platinum | 100-day wake streak, 26 weeks gym | 5,000 |
| Diamond | 365-day average 80+, all Gold achievements | 15,000 |

---

## Security Architecture

### Network Security

```
Internet
    │
[Tailscale Mesh VPN]
    │
    ├── Home Hub (Arch Linux)
    │   └── Docker network (internal)
    │       ├── Home Assistant (host network for mDNS)
    │       ├── Zigbee2MQTT
    │       ├── Mosquitto (port 1883, internal only)
    │       ├── TimescaleDB (port 5432, internal only)
    │       └── LifeOps API (port 8000, Tailscale only)
    │
    ├── Summer Cabin Hub (Phase 2)
    └── Winter Cabin Hub (Phase 3)
```

### Authentication

| Component | Method |
|-----------|--------|
| LifeOps API | JWT + mTLS |
| Home Assistant | Long-lived access tokens |
| Mobile App | JWT with FaceID/TouchID unlock |
| Web Dashboard | JWT with session |

### Data Encryption

| Layer | Method |
|-------|--------|
| In Transit | TLS 1.3 (ChaCha20-Poly1305) |
| At Rest | SQLite encryption (optional) |
| Backups | age encryption |

### Remote Access

- **Tailscale** for all remote access
- No ports exposed to public internet
- Peer-to-peer when possible (<5ms overhead)
- Relay fallback for NAT traversal

---

## Client Applications

### iPhone App (Native Swift)

**Purpose**: Daily driver, quick actions, notifications

**Data Fetched**:
- `GET /api/today` - Today's scores (~500 bytes)
- `WS /api/events` - Real-time updates (push only)
- `GET /api/quick-actions` - Scene buttons (~200 bytes)

**Features**:
- Life Score display
- Domain score cards
- Quick action buttons (lights, scenes)
- Habit check-in
- Push notifications

**Not Included**:
- Full analytics (use web)
- Historical charts (use web)
- Large data exports (use web)

### Web Dashboard (Next.js)

**Purpose**: Full analytics, deep dive, configuration

**Data Fetched**:
- Full API access
- Historical data on demand
- Export capabilities

**Features**:
- Comprehensive charts and trends
- Correlation analysis (temp vs sleep)
- Achievement browser
- Settings and configuration
- Keyboard shortcuts

### Linux Daemon

**Purpose**: Background sync, system tray, notifications

**Features**:
- Sync status indicator
- Desktop notifications
- Quick action menu
- Minimal resource usage

---

## Implementation Phases

### Phase 1: Foundation (Weeks 1-4)

**Goal**: Basic home automation + data collection

| Week | Tasks |
|------|-------|
| 1 | Set up Docker stack on Arch Linux |
| 1 | Install Home Assistant + Zigbee2MQTT |
| 1 | Configure Plejd Gateway integration |
| 2 | Install and pair Zigbee sensors |
| 2 | Set up basic automations (motion → lights) |
| 3 | Deploy TimescaleDB, create schema |
| 3 | Build Oura sync service |
| 4 | Build calendar sync service |
| 4 | Create basic API endpoints |

**Deliverable**: Working home automation, data flowing into database

### Phase 2: Gamification (Weeks 5-8)

**Goal**: Life Score calculation + habit tracking

| Week | Tasks |
|------|-------|
| 5 | Implement domain score calculations |
| 5 | Build Life Score aggregation |
| 6 | Create XP and leveling system |
| 6 | Implement streak tracking |
| 7 | Build achievement system |
| 7 | Create daily/weekly challenge generator |
| 8 | Build notification system |
| 8 | Test and refine scoring algorithms |

**Deliverable**: Full gamification engine running

### Phase 3: Mobile App (Weeks 9-12)

**Goal**: iOS app for daily use

| Week | Tasks |
|------|-------|
| 9 | Set up Swift project |
| 9 | Build API client |
| 10 | Create dashboard UI (Life Score, domains) |
| 10 | Implement quick actions |
| 11 | Add habit check-in |
| 11 | Implement push notifications |
| 12 | Add FaceID authentication |
| 12 | TestFlight beta |

**Deliverable**: Functional iOS app

### Phase 4: Web Dashboard (Weeks 13-16)

**Goal**: Full analytics dashboard

| Week | Tasks |
|------|-------|
| 13 | Set up Next.js project |
| 13 | Build authentication flow |
| 14 | Create Life Score trends page |
| 14 | Build domain detail pages |
| 15 | Implement achievement browser |
| 15 | Add correlation insights |
| 16 | Create settings/configuration UI |
| 16 | Deploy and test |

**Deliverable**: Web dashboard with full analytics

### Phase 5: Behavior Optimization (Weeks 17-20)

**Goal**: Implement behavior change interventions

| Week | Tasks |
|------|-------|
| 17 | Implement wind-down routine automation |
| 17 | Build morning wake routine (Plejd sunrise) |
| 18 | Create work boundary notifications |
| 18 | Implement Oura-guided workout suggestions |
| 19 | Build correlation engine (temp vs sleep) |
| 19 | Create weekly review generator |
| 20 | Refine intervention timing |
| 20 | User testing and adjustment |

**Deliverable**: Active behavior change system

### Phase 6: Cabins (Future)

**Goal**: Extend to cabin locations

| Tasks |
|-------|
| Purchase and configure Pi 4 for summer cabin |
| Set up Tailscale VPN connection |
| Deploy Home Assistant + sensors |
| Configure sync to main hub |
| Repeat for winter cabin |

**Deliverable**: Multi-location system

---

## Shopping List

### Budget Overview

**Total Budget**: 10,000 NOK (for LifeOps infrastructure only)

**Separate Budgets**:
- Kitchen renovation: Plejd Gateway + new dimmers (not included below)
- Electrician work: Lighting installation (not included below)

### Phase 1 Hardware (Home) - ~1,005 NOK

**Approach**: DIY sensors using ESP32-C3 + ESPHome for smallest size and full customization.

| Item | Quantity | Est. Price (NOK) | Source |
|------|----------|------------------|--------|
| Sonoff Zigbee 3.0 USB Dongle Plus | 1 | 250 | AliExpress |
| ESP32-C3 Super Mini | 10 | 180 | AliExpress |
| BME280 (temp/humidity/pressure) | 5 | 125 | AliExpress |
| AM312 mini PIR (motion) | 5 | 50 | AliExpress |
| Reed switch + magnet | 5 | 40 | AliExpress |
| 3.7V LiPo 500mAh | 5 | 150 | AliExpress |
| TP4056 USB charger boards | 5 | 40 | AliExpress |
| Dupont wires, solder, misc | 1 | 70 | AliExpress |
| 3D printing filament | 1 | 100 | Local |
| **Phase 1 Total** | | **~1,005** | |

### Phase 2-3 Hardware (Cabins) - ~3,500 NOK

| Item | Quantity | Est. Price (NOK) | Source |
|------|----------|------------------|--------|
| Raspberry Pi 4 (4GB) | 2 | 1,400 | Komplett |
| Pi 4 Case + Power Supply | 2 | 400 | Komplett |
| MicroSD 64GB | 2 | 200 | Komplett |
| Sonoff Zigbee USB Dongle | 2 | 500 | AliExpress |
| DIY sensor components | ~10 | 1,000 | AliExpress |
| **Cabin Total** | | **~3,500** | |

### Budget Summary

| Allocation | Amount (NOK) | Percentage |
|------------|--------------|------------|
| Phase 1: Home | 1,005 | 10% |
| Phase 2-3: Cabins | 3,500 | 35% |
| Contingency | 5,495 | 55% |
| **Total Budget** | **10,000** | 100% |

### External Costs (Not in Budget)

| Item | Source | Notes |
|------|--------|-------|
| Plejd Gateway (GWY-01) | Elektroimportøren | Kitchen renovation budget, 25% discount |
| Plejd DIM-01/DIM-02 | Elektroimportøren | Kitchen renovation budget, 25% discount |
| Electrician labor | - | Kitchen renovation budget |

---

## Appendix: Configuration Files

### ESPHome Sensor Configurations

#### Multi-Sensor (Bedroom/Living Room/Bathroom)

```yaml
# bedroom-sensor.yaml
esphome:
  name: bedroom-sensor
  friendly_name: Bedroom Sensor

esp32:
  board: esp32-c3-devkitm-1
  framework:
    type: esp-idf

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  fast_connect: true

api:
  encryption:
    key: !secret api_encryption_key

ota:
  password: !secret ota_password

logger:
  level: WARN

# Deep sleep for battery optimization
deep_sleep:
  id: deep_sleep_control
  run_duration: 30s
  sleep_duration: 5min

# BME280 Temperature/Humidity/Pressure
i2c:
  sda: GPIO6
  scl: GPIO7

sensor:
  - platform: bme280_i2c
    temperature:
      name: "Bedroom Temperature"
      id: bedroom_temp
      oversampling: 2x
    humidity:
      name: "Bedroom Humidity"
      id: bedroom_humidity
      oversampling: 2x
    pressure:
      name: "Bedroom Pressure"
    address: 0x76
    update_interval: 60s

  - platform: wifi_signal
    name: "Bedroom Sensor WiFi"
    update_interval: 60s

  - platform: uptime
    name: "Bedroom Sensor Uptime"

# AM312 PIR Motion Sensor
binary_sensor:
  - platform: gpio
    pin:
      number: GPIO4
      mode: INPUT_PULLDOWN
    name: "Bedroom Motion"
    device_class: motion
    filters:
      - delayed_off: 30s
    on_press:
      then:
        - deep_sleep.prevent: deep_sleep_control
    on_release:
      then:
        - delay: 60s
        - deep_sleep.allow: deep_sleep_control

# Battery voltage monitoring (if using LiPo)
  - platform: adc
    pin: GPIO0
    name: "Bedroom Sensor Battery"
    update_interval: 60s
    attenuation: 11db
    filters:
      - multiply: 2  # Voltage divider ratio
```

#### Door Sensor (Entry)

```yaml
# entry-door.yaml
esphome:
  name: entry-door
  friendly_name: Entry Door

esp32:
  board: esp32-c3-devkitm-1
  framework:
    type: esp-idf

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  fast_connect: true

api:
  encryption:
    key: !secret api_encryption_key

ota:
  password: !secret ota_password

logger:
  level: WARN

# Deep sleep - wake on door state change
deep_sleep:
  id: deep_sleep_control
  run_duration: 10s
  sleep_duration: 60min
  wakeup_pin:
    number: GPIO4
    allow_other_uses: true

binary_sensor:
  - platform: gpio
    pin:
      number: GPIO4
      mode: INPUT_PULLUP
      inverted: true
    name: "Entry Door"
    device_class: door
    filters:
      - delayed_on: 100ms
      - delayed_off: 100ms
```

#### Smart Button (Bedside)

```yaml
# bedroom-button.yaml
esphome:
  name: bedroom-button
  friendly_name: Bedroom Button

esp32:
  board: esp32-c3-devkitm-1
  framework:
    type: esp-idf

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password
  fast_connect: true

api:
  encryption:
    key: !secret api_encryption_key

ota:
  password: !secret ota_password

logger:
  level: WARN

deep_sleep:
  run_duration: 10s
  sleep_duration: 60min
  wakeup_pin:
    number: GPIO4
    allow_other_uses: true

binary_sensor:
  - platform: gpio
    pin:
      number: GPIO4
      mode: INPUT_PULLUP
      inverted: true
    name: "Bedroom Button"
    filters:
      - delayed_on: 50ms
    on_multi_click:
      # Single press - toggle bedroom lights
      - timing:
          - ON for at most 0.5s
          - OFF for at least 0.3s
        then:
          - homeassistant.event:
              event: esphome.button_press
              data:
                button: bedroom
                action: single
      # Double press - goodnight scene
      - timing:
          - ON for at most 0.5s
          - OFF for at most 0.3s
          - ON for at most 0.5s
          - OFF for at least 0.2s
        then:
          - homeassistant.event:
              event: esphome.button_press
              data:
                button: bedroom
                action: double
      # Long press - all lights off
      - timing:
          - ON for at least 1s
        then:
          - homeassistant.event:
              event: esphome.button_press
              data:
                button: bedroom
                action: hold
```

### Home Assistant Example Automations

```yaml
# automations.yaml

# Morning wake-up routine (gradual sunrise)
- alias: "Morning Wake Routine"
  trigger:
    - platform: time
      at: "05:30:00"
  condition:
    - condition: time
      weekday:
        - mon
        - tue
        - wed
        - thu
        - fri
  action:
    - service: light.turn_on
      entity_id: light.bedroom_plejd
      data:
        brightness_pct: 1
        transition: 1800  # 30 minutes gradual increase

# Motion-activated bathroom with music
- alias: "Bathroom Motion Lights"
  trigger:
    - platform: state
      entity_id: binary_sensor.bathroom_motion  # ESPHome sensor
      to: "on"
  action:
    - service: light.turn_on
      entity_id: light.bathroom_plejd
    - condition: time
      after: "06:00:00"
      before: "09:00:00"
    - service: media_player.play_media
      entity_id: media_player.bathroom_speaker
      data:
        media_content_id: "spotify:playlist:morning"
        media_content_type: "spotify"

# Wind-down routine
- alias: "Wind Down Start"
  trigger:
    - platform: time
      at: "21:00:00"
  action:
    - service: light.turn_on
      entity_id:
        - light.living_room_plejd
        - light.bedroom_plejd
      data:
        brightness_pct: 30
        color_temp: 500  # Warm
    - service: notify.mobile_app
      data:
        title: "Wind Down"
        message: "Time to start your evening routine"

# Bedroom button handler
- alias: "Bedroom Button Actions"
  trigger:
    - platform: event
      event_type: esphome.button_press
      event_data:
        button: bedroom
  action:
    - choose:
        # Single press - toggle bedroom light
        - conditions:
            - condition: template
              value_template: "{{ trigger.event.data.action == 'single' }}"
          sequence:
            - service: light.toggle
              entity_id: light.bedroom_plejd
        # Double press - goodnight scene
        - conditions:
            - condition: template
              value_template: "{{ trigger.event.data.action == 'double' }}"
          sequence:
            - service: light.turn_off
              entity_id: all
            - service: input_boolean.turn_on
              entity_id: input_boolean.goodnight_triggered
        # Long press - all lights off
        - conditions:
            - condition: template
              value_template: "{{ trigger.event.data.action == 'hold' }}"
          sequence:
            - service: light.turn_off
              entity_id: all

# Arrival detection
- alias: "Arrival Home"
  trigger:
    - platform: state
      entity_id: binary_sensor.entry_door  # ESPHome door sensor
      to: "on"
  condition:
    - condition: state
      entity_id: binary_sensor.entry_motion  # ESPHome motion sensor
      state: "off"
      for:
        minutes: 30  # No motion for 30 min = was away
  action:
    - service: light.turn_on
      entity_id: light.entrance_plejd
    - service: light.turn_on
      entity_id: light.living_room_plejd
      data:
        brightness_pct: 80

# Sleep environment logging
- alias: "Log Sleep Environment"
  trigger:
    - platform: time
      at: "06:00:00"
  action:
    - service: rest_command.log_sleep_environment
      data:
        temperature: "{{ states('sensor.bedroom_temperature') }}"
        humidity: "{{ states('sensor.bedroom_humidity') }}"
```

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-01 | 1.0 | Initial architecture document |

---

*This document is the source of truth for LifeOps technical decisions. Update as the system evolves.*
