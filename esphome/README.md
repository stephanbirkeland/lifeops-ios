# LifeOps ESPHome Configurations

ESPHome firmware configurations for DIY sensors.

## Files

| File | Purpose |
|------|---------|
| `common.yaml` | Shared configuration (WiFi, API, OTA) |
| `secrets.yaml.example` | Template for secrets - copy to `secrets.yaml` |
| `bedroom-sensor.yaml` | Bedroom multi-sensor (temp/humidity/motion) |
| `living-room-sensor.yaml` | Living room multi-sensor |
| `bathroom-sensor.yaml` | Bathroom multi-sensor (high humidity alerts) |
| `entry-sensor.yaml` | Entry hallway multi-sensor |
| `entry-door.yaml` | Entry door contact sensor |
| `bedroom-button.yaml` | Bedside scene button |

## Setup

### 1. Create secrets file

```bash
cp secrets.yaml.example secrets.yaml
```

Edit `secrets.yaml` with your values:
- WiFi SSID and password
- Generate API encryption key: `python3 -c "import secrets; print(secrets.token_urlsafe(32))"`
- Set OTA password

### 2. Flash first device

Connect ESP32-C3 via USB and use ESPHome dashboard:

```bash
# From LifeOps root
docker compose up -d esphome
```

Access ESPHome at `http://localhost:6052`

1. Click "New Device"
2. Give it a name
3. Select ESP32-C3
4. Click "Install" → "Plug into computer"

### 3. Adopt existing config

After initial flash:
1. In ESPHome dashboard, click on the device
2. Click "Adopt" if prompted
3. Replace generated YAML with one of these configs
4. Update OTA

## Hardware Wiring

### Multi-Sensor (BME280 + PIR)

| ESP32-C3 Pin | Component |
|--------------|-----------|
| 3V3 | BME280 VCC, AM312 VCC |
| GND | BME280 GND, AM312 GND |
| GPIO6 | BME280 SDA |
| GPIO7 | BME280 SCL |
| GPIO4 | AM312 OUT |
| GPIO0 | Battery voltage (via divider) |

### Door Sensor (Reed Switch)

| ESP32-C3 Pin | Component |
|--------------|-----------|
| 3V3 | Battery + |
| GND | Battery -, Reed switch terminal 2 |
| GPIO4 | Reed switch terminal 1 |

### Button

| ESP32-C3 Pin | Component |
|--------------|-----------|
| 3V3 | Battery + |
| GND | Battery -, Button terminal 2 |
| GPIO4 | Button terminal 1 |

## Power Options

### USB Powered (Recommended for bathroom)
- Direct USB-C connection
- No battery management needed
- Always-on, instant response

### LiPo Battery (Multi-sensors)
- 500mAh 3.7V LiPo
- TP4056 charge controller
- Voltage divider for monitoring
- 2-4 weeks between charges

### CR2032 (Door sensor, button)
- Low power, long sleep
- Wake on GPIO interrupt
- 6-12 months battery life

## Deep Sleep Behavior

| Sensor Type | Wake Duration | Sleep Duration | Wake Trigger |
|-------------|---------------|----------------|--------------|
| Multi-sensor | 30s | 5min | Timer, motion |
| Door sensor | 10s | 60min | Door state change |
| Button | 10s | 60min | Button press |

## Home Assistant Integration

Sensors are auto-discovered via ESPHome integration:

1. Go to Settings → Devices & Services
2. ESPHome devices appear automatically
3. Click "Configure" to add

## Calibration

### Temperature Offset

If readings are consistently off, add offset in sensor config:

```yaml
filters:
  - offset: -1.5  # Subtract 1.5°C
```

### Humidity Calibration

Compare with known good hygrometer and adjust:

```yaml
filters:
  - calibrate_linear:
      - 0.0 -> 0.0
      - 100.0 -> 95.0  # If reading 100 when actual is 95
```

## Troubleshooting

### Device won't connect to WiFi
- Check `secrets.yaml` credentials
- Try `fast_connect: false` temporarily
- Check router for MAC filtering

### Battery drains quickly
- Verify deep sleep is working (check uptime sensor)
- Reduce update_interval
- Check for components preventing sleep

### Motion sensor false triggers
- Increase `delayed_off` filter
- Point away from heat sources
- Check for drafts
