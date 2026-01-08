# LifeOps Hardware Guide

Detailed hardware specifications, shopping lists, and assembly instructions for the LifeOps system.

---

## Table of Contents

1. [Overview](#overview)
2. [Main Hub](#main-hub)
3. [DIY Sensors](#diy-sensors)
4. [Plejd Lighting](#plejd-lighting)
5. [Zigbee Infrastructure](#zigbee-infrastructure)
6. [Cabin Hardware](#cabin-hardware)
7. [Shopping Lists](#shopping-lists)
8. [Component Specifications](#component-specifications)
9. [Wiring Diagrams](#wiring-diagrams)
10. [Assembly Instructions](#assembly-instructions)

---

## Overview

### Hardware Philosophy

- **DIY sensors** - Smallest possible form factor, fully customizable
- **Existing infrastructure** - Arch Linux desktop as main hub (no additional cost)
- **Quality over quantity** - Buy what's needed, large contingency for future
- **Local control** - WiFi (ESPHome) and Zigbee, no cloud dependencies

### Budget Allocation

| Category | Amount (NOK) | Notes |
|----------|--------------|-------|
| Phase 1: Home | 1,005 | DIY sensors, Zigbee dongle |
| Phase 2-3: Cabins | 3,500 | Pi 4 hubs, sensors |
| Contingency | 5,495 | Future expansion |
| **Total** | **10,000** | LifeOps infrastructure only |

**Separate budgets:**
- Plejd Gateway + dimmers (kitchen renovation)
- Electrician labor (kitchen renovation)

---

## Main Hub

### Current Hardware

**Arch Linux Desktop**

| Spec | Value |
|------|-------|
| RAM | 32 GB |
| Status | Always-on, 24/7 |
| Location | Home apartment |
| OS | Arch Linux |

This machine serves as the central hub. No additional hardware purchase needed.

### Required Software

```
Docker + Docker Compose
├── Home Assistant
├── ESPHome
├── Zigbee2MQTT (optional, profile-based)
├── Mosquitto (MQTT broker)
├── TimescaleDB (PostgreSQL + time-series)
├── LifeOps API (FastAPI)
└── LifeOps Web (Next.js)
```

### USB Devices

| Device | Port | Purpose |
|--------|------|---------|
| Sonoff Zigbee 3.0 USB Dongle Plus | /dev/ttyUSB0 | Zigbee coordinator |

---

## DIY Sensors

### Platform: ESP32-C3 Super Mini

**Why ESP32-C3 Super Mini?**

| Feature | Value |
|---------|-------|
| Size | 22mm × 18mm |
| WiFi | 2.4 GHz 802.11 b/g/n |
| Bluetooth | BLE 5.0 |
| Deep Sleep | ~5 µA |
| Operating Voltage | 3.3V |
| GPIO | 11 pins |
| Price | ~18 NOK each |

The ESP32-C3 Super Mini is the smallest widely-available ESP32 board, ideal for compact sensor enclosures.

### Sensor Types

#### 1. Multi-Sensor (Room Monitoring)

**Purpose:** Temperature, humidity, pressure, and motion detection

**Components:**
| Component | Model | Purpose | Price (NOK) |
|-----------|-------|---------|-------------|
| Microcontroller | ESP32-C3 Super Mini | Main controller | 18 |
| Temp/Humidity/Pressure | BME280 | Environmental sensing | 25 |
| Motion | AM312 mini PIR | Presence detection | 10 |
| Battery | 3.7V LiPo 500mAh | Power | 30 |
| Charger | TP4056 | USB charging | 8 |
| **Total** | | | **~91** |

**Dimensions (estimated):** 30mm × 25mm × 15mm (with 3D printed case)

**Placement:**
- Bedroom (sleep environment monitoring)
- Living room (comfort, presence)
- Bathroom (humidity, motion for auto-lights)
- Entry (motion for hallway lights)

#### 2. Door Sensor

**Purpose:** Entry/exit detection, arrival automation

**Components:**
| Component | Model | Purpose | Price (NOK) |
|-----------|-------|---------|-------------|
| Microcontroller | ESP32-C3 Super Mini | Main controller | 18 |
| Contact | Reed switch + magnet | Door state | 8 |
| Battery | CR2032 or LiPo | Power | 10-30 |
| **Total** | | | **~36-56** |

**Dimensions (estimated):** 25mm × 18mm × 10mm

**Features:**
- Wake-on-change (GPIO interrupt)
- Years of battery life with deep sleep
- Instant state reporting

**Placement:**
- Main entry door

#### 3. Smart Button

**Purpose:** Manual scene control, bedside automation

**Components:**
| Component | Model | Purpose | Price (NOK) |
|-----------|-------|---------|-------------|
| Microcontroller | ESP32-C3 Super Mini | Main controller | 18 |
| Button | Tactile switch (12mm) | User input | 2 |
| Battery | CR2032 | Power | 10 |
| **Total** | | | **~30** |

**Dimensions (estimated):** 25mm × 18mm × 8mm

**Actions:**
- Single press: Toggle bedroom light
- Double press: Goodnight scene (all lights off)
- Long press: All lights off immediately

**Placement:**
- Bedroom (bedside)

### Sensor Firmware: ESPHome

ESPHome provides:
- Native Home Assistant integration
- OTA (over-the-air) updates
- Deep sleep support
- Encrypted API communication
- Easy YAML configuration

---

## Plejd Lighting

### Current Installation

| Location | Device | Type | Status |
|----------|--------|------|--------|
| Bedroom | Corner lamp inline dimmer | DIM-01/02 | Installed |

### Planned Installation (Kitchen Renovation)

| Location | Device | Type | Purpose |
|----------|--------|------|---------|
| Living room | DIM-01 × 2 | Dimmer | Ceiling lights |
| Kitchen | DIM-02 or LED-10 | Dimmer | Cabinet lighting |
| Bathroom | CTL-01 × 2 | On/Off | Ceiling + mirror |
| Entrance | CTL-01 | On/Off | Ceiling |
| Bedroom | DIM-01 | Dimmer | Ceiling light |
| All | GWY-01 | Gateway | Network control |

### Plejd Gateway (GWY-01)

The gateway enables:
- Network-based control (no Bluetooth on hub required)
- Integration with Home Assistant via local API
- Lower latency than Bluetooth
- More reliable than direct Bluetooth connection

**Note:** Gateway and expansion dimmers are on the kitchen renovation budget (25% discount at Elektroimportøren).

---

## Zigbee Infrastructure

### Coordinator

**Sonoff Zigbee 3.0 USB Dongle Plus**

| Spec | Value |
|------|-------|
| Chip | CC2652P |
| Firmware | Coordinator firmware |
| Range | ~200m open air, ~10-30m indoor |
| Devices supported | 200+ |
| Price | ~250 NOK |

### Current Status

The Zigbee dongle is purchased for future expansion. Primary sensors use WiFi (ESPHome) for the smallest form factor.

**Future Zigbee use cases:**
- Commercial sensors if DIY doesn't work out
- IKEA TRÅDFRI bulbs
- Aqara devices
- Battery-powered devices that benefit from mesh networking

### Software

Zigbee2MQTT is included in Docker Compose with a profile flag. Enable when Zigbee devices are added:

```bash
docker compose --profile zigbee up -d
```

---

## Cabin Hardware

### Phase 2: Summer Cabin

| Component | Model | Purpose | Price (NOK) |
|-----------|-------|---------|-------------|
| Hub | Raspberry Pi 4 (4GB) | Local processing | 700 |
| Case | Official Pi 4 case | Protection | 100 |
| Power | Official USB-C PSU | Reliable power | 100 |
| Storage | SanDisk 64GB microSD | OS + data | 100 |
| Zigbee | Sonoff USB Dongle | Coordinator | 250 |
| Sensors | DIY ESP32-C3 × 3 | Room sensors | 300 |
| **Total** | | | **~1,550** |

### Phase 3: Winter Cabin

Same hardware as summer cabin: **~1,550 NOK**

### Cabin Network

Both cabins have fiber internet. Tailscale VPN connects to main hub:

```
Home Hub (Arch Linux)
    │
    ├── Tailscale
    │
    ├─── Summer Cabin Pi
    └─── Winter Cabin Pi
```

---

## Shopping Lists

### Phase 1: Home (AliExpress Order)

Order from AliExpress for best prices on DIY components:

| Item | Qty | Unit Price | Total | Link Notes |
|------|-----|------------|-------|------------|
| ESP32-C3 Super Mini | 10 | 18 | 180 | Search "ESP32-C3 Super Mini" |
| BME280 (GY-BME280) | 5 | 25 | 125 | I2C version, 3.3V |
| AM312 Mini PIR | 5 | 10 | 50 | Smallest PIR sensor |
| Reed switch + magnet | 5 | 8 | 40 | Surface mount type |
| 3.7V LiPo 500mAh | 5 | 30 | 150 | JST connector |
| TP4056 USB-C charger | 5 | 8 | 40 | With protection circuit |
| Dupont wires (kit) | 1 | 30 | 30 | Female-female, male-female |
| Soldering supplies | 1 | 40 | 40 | Solder, flux |
| **AliExpress Total** | | | **655** | |

| Item | Qty | Price | Source |
|------|-----|-------|--------|
| Sonoff Zigbee 3.0 USB Dongle Plus | 1 | 250 | AliExpress or Amazon |
| 3D printing filament (PLA) | 1 | 100 | Local store |
| **Additional Total** | | **350** | |

**Phase 1 Grand Total: ~1,005 NOK**

### Phase 2-3: Cabins (Komplett + AliExpress)

**Komplett.no order (per cabin):**

| Item | Qty | Price | Notes |
|------|-----|-------|-------|
| Raspberry Pi 4 Model B 4GB | 1 | 700 | Official retailer |
| Pi 4 Case + Fan | 1 | 100 | |
| Official USB-C Power Supply | 1 | 100 | 15W |
| SanDisk Ultra 64GB microSD | 1 | 100 | Class 10, A1 |
| **Per Cabin Total** | | **1,000** | |

**AliExpress order (per cabin):**

| Item | Qty | Price |
|------|-----|-------|
| Sonoff Zigbee USB Dongle | 1 | 250 |
| ESP32-C3 Super Mini | 5 | 90 |
| BME280 | 2 | 50 |
| AM312 PIR | 2 | 20 |
| Reed switch | 2 | 16 |
| LiPo 500mAh | 2 | 60 |
| TP4056 | 2 | 16 |
| **Per Cabin AliExpress** | | **~500** |

**Per Cabin Total: ~1,500-1,550 NOK**
**Two Cabins Total: ~3,000-3,100 NOK**

---

## Component Specifications

### ESP32-C3 Super Mini Pinout

```
                 ┌─────────┐
            3V3 ─┤1      12├─ GND
            3V3 ─┤2      11├─ GPIO10
          RESET ─┤3      10├─ GPIO9
          GPIO4 ─┤4       9├─ GPIO8
          GPIO5 ─┤5       8├─ GPIO7 (I2C SCL)
          GPIO6 ─┤6       7├─ GPIO6 (I2C SDA)
                 └─────────┘
                   USB-C
```

**Recommended Pin Usage:**
| Pin | Function | Use |
|-----|----------|-----|
| GPIO4 | Digital Input | PIR motion / Reed switch / Button |
| GPIO5 | Digital Input | Backup input |
| GPIO6 | I2C SDA | BME280 data |
| GPIO7 | I2C SCL | BME280 clock |
| GPIO0 | ADC | Battery voltage monitoring |

### BME280 Specifications

| Parameter | Range | Accuracy |
|-----------|-------|----------|
| Temperature | -40°C to +85°C | ±1.0°C |
| Humidity | 0-100% RH | ±3% RH |
| Pressure | 300-1100 hPa | ±1 hPa |

**Power Consumption:**
- Active (forced mode): 2.7 µA typical
- Sleep mode: 0.1 µA

### AM312 Mini PIR Specifications

| Parameter | Value |
|-----------|-------|
| Size | 10mm × 23mm |
| Detection angle | 100° cone |
| Detection range | 3-5 meters |
| Operating voltage | 2.7-12V |
| Quiescent current | <50 µA |
| Output | Digital high (3.3V) on motion |
| Delay time | ~2.5 seconds (adjustable) |

### LiPo Battery Considerations

**500mAh 3.7V LiPo:**
- Charge voltage: 4.2V max
- Discharge cutoff: 3.0V (protect circuit)
- Estimated life:
  - Multi-sensor (5min wake): ~2-4 weeks
  - Door sensor (wake on change): ~6-12 months
  - Button (wake on press): ~6-12 months

**TP4056 with protection:**
- Overcharge protection
- Over-discharge protection
- Short circuit protection
- USB-C or micro-USB charging

---

## Wiring Diagrams

### Multi-Sensor Wiring

```
                    ESP32-C3 Super Mini
                   ┌─────────────────────┐
                   │                     │
    TP4056 ────────┤ 3V3           GND  ├─────┬──────────┐
    (3.3V out)     │                     │     │          │
                   │ GPIO6 (SDA)        │     │   BME280 │
                   │    │                │     │   ┌───┐  │
                   │    └───────────────────────────┤SDA│  │
                   │                     │     │   │SCL│  │
                   │ GPIO7 (SCL)        │     │   │VCC├──┘
                   │    │                │     │   │GND├──┤
                   │    └───────────────────────────┤   │  │
                   │                     │     │   └───┘  │
                   │ GPIO4 ─────────────────────┐         │
                   │                     │     │  AM312   │
                   │                     │     │  ┌───┐   │
                   │                     │     └──┤OUT│   │
                   │                     │        │VCC├───┤
                   └─────────────────────┘        │GND├───┘
                                                  └───┘

    Power Circuit:
    ┌─────────┐      ┌─────────┐
    │  LiPo   │──────┤ TP4056  │────── 3.3V to ESP32
    │ 500mAh  │      │         │
    └─────────┘      └─────────┘
                         │
                      USB-C (charging)
```

### Door Sensor Wiring

```
                    ESP32-C3 Super Mini
                   ┌─────────────────────┐
                   │                     │
    CR2032 ────────┤ 3V3           GND  ├───────┐
    (or LiPo)      │                     │       │
                   │ GPIO4 ─────────────────┬───┤
                   │   (INPUT_PULLUP)    │   │   │
                   └─────────────────────┘   │   │
                                             │   │
                                        Reed Switch
                                        (normally open)
                                             │   │
                                             └───┘

    Magnet placed on door frame, switch on door
```

### Smart Button Wiring

```
                    ESP32-C3 Super Mini
                   ┌─────────────────────┐
                   │                     │
    CR2032 ────────┤ 3V3           GND  ├───────┐
                   │                     │       │
                   │ GPIO4 ─────────────────┬───┤
                   │   (INPUT_PULLUP)    │   │   │
                   └─────────────────────┘   │   │
                                             │   │
                                        ┌────┴───┤
                                        │ Button │
                                        │ (N.O.) │
                                        └────────┘
```

---

## Assembly Instructions

### Multi-Sensor Assembly

**Tools needed:**
- Soldering iron (fine tip)
- Solder (0.5mm recommended)
- Wire strippers
- Heat shrink tubing
- 3D printed case (see SETUP.md)

**Steps:**

1. **Prepare ESP32-C3**
   - Check that it powers on via USB
   - Flash ESPHome firmware before assembly

2. **Wire BME280**
   - VCC → 3.3V
   - GND → GND
   - SDA → GPIO6
   - SCL → GPIO7
   - Use ~30mm wires, heat shrink on joints

3. **Wire AM312 PIR**
   - VCC → 3.3V
   - GND → GND
   - OUT → GPIO4
   - Position at edge of enclosure for detection

4. **Wire TP4056 Power**
   - LiPo + to TP4056 B+
   - LiPo - to TP4056 B-
   - TP4056 OUT+ → ESP32 3V3
   - TP4056 OUT- → ESP32 GND

5. **Test Assembly**
   - Power on, verify Home Assistant discovery
   - Test motion detection
   - Test temperature/humidity readings
   - Verify deep sleep / wake behavior

6. **Enclose**
   - Place components in 3D printed case
   - Ensure PIR sensor lens is visible
   - Leave USB port accessible for charging

### Door Sensor Assembly

**Steps:**

1. **Flash ESPHome** to ESP32-C3

2. **Wire Reed Switch**
   - One terminal to GPIO4
   - Other terminal to GND
   - Use INPUT_PULLUP in firmware

3. **Wire Battery**
   - CR2032 holder or LiPo with TP4056
   - For CR2032: + to 3V3, - to GND

4. **Test**
   - Verify state changes in Home Assistant
   - Test wake from deep sleep
   - Measure current draw in sleep

5. **Mount**
   - Attach sensor body to door
   - Attach magnet to door frame
   - Ensure <10mm gap when closed

### Smart Button Assembly

**Steps:**

1. **Flash ESPHome** with button firmware

2. **Wire Button**
   - One terminal to GPIO4
   - Other terminal to GND
   - Use INPUT_PULLUP, inverted in firmware

3. **Wire Battery**
   - CR2032 for longest life
   - Wake-on-press via GPIO interrupt

4. **Test**
   - Verify single/double/long press events
   - Test Home Assistant automations

5. **Mount**
   - Bedside table or wall-mounted
   - Ensure button is easily accessible

---

## Troubleshooting

### ESP32-C3 Won't Flash

- Try holding BOOT button while connecting USB
- Use a data-capable USB-C cable (not charge-only)
- Check esptool.py is latest version

### BME280 Not Detected

- Check I2C address (0x76 or 0x77)
- Verify SDA/SCL connections
- Try reducing I2C speed in ESPHome

### PIR False Triggers

- Avoid pointing at heat sources
- Use delayed_off filter in ESPHome
- Check for drafts near sensor

### Short Battery Life

- Verify deep sleep is working
- Check for components not sleeping
- Measure current with multimeter

### WiFi Connection Issues

- Use `fast_connect: true` in ESPHome
- Set static IP for faster reconnection
- Check signal strength (use `wifi_signal` sensor)

---

## Revision History

| Date | Version | Changes |
|------|---------|---------|
| 2025-01 | 1.0 | Initial hardware documentation |

---

*Reference ARCHITECTURE.md for system design and SETUP.md for installation instructions.*
