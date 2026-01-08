# LifeOps Device Inventory

This document catalogs all devices and smart home equipment that LifeOps will integrate with.

---

## Locations

| Location | Type | Distance |
|----------|------|----------|
| Home | Apartment | - |
| Summer Cabin | Cabin | Close by |
| Winter Cabin | Cabin | ~4 hours |

---

## Computers

| Device | Location | OS | Primary Use |
|--------|----------|-----|-------------|
| Linux PC | Home | Linux | Personal use |
| Linux PC | Summer cabin | Linux | Personal use |
| Linux PC | Winter cabin | Linux | Personal use |
| MacBook | Mobile | macOS | Work and misc |
| iPad | Mobile | iPadOS | Work and misc |
| Raspberry Pi | TBD | Linux | Available for projects |

---

## Mobile Devices

| Device | Platform | Role |
|--------|----------|------|
| iPhone | iOS | Daily driver, primary mobile device |

---

## Wearables

| Device | Type | Data Provided | Ecosystem |
|--------|------|---------------|-----------|
| Oura Ring | Health tracker | Sleep, readiness, activity, HRV, temperature | Oura app, API available |

### Oura Ring Capabilities
- **Sleep tracking**: Duration, stages, efficiency, timing
- **Readiness score**: Daily recovery assessment
- **Activity tracking**: Steps, calories, movement
- **Heart rate**: Resting HR, HRV (heart rate variability)
- **Body temperature**: Deviation from baseline
- **SpO2**: Blood oxygen (depending on model)

### Oura Integration Value for LifeOps
The Oura ring is a **goldmine** for LifeOps:
- Sleep Agent can use actual sleep data, not just bedtime
- Fitness Agent can factor in readiness for workout planning
- Identifies patterns between activities and sleep quality
- Objective data vs. subjective "how do I feel"

**API**: Oura provides a REST API for accessing personal data

---

## Audio & Visual

| Device | Location | Room | Ecosystem | Capabilities |
|--------|----------|------|-----------|--------------|
| Samsung TV | Home | Living room | Samsung/Tizen | Display, streaming, smart features |
| Samsung speakers | Home | Living room | Samsung | Audio output |
| Samsung TV | Home | Bedroom | Samsung/Tizen | Display, streaming |
| Samsung speakers | Home | Bedroom | Samsung | Audio output |
| Google Audio | Home | Bathroom | Google Home | Voice control, music, routines |
| HomePod | Home | Living room | Apple HomeKit | Voice control, music, home hub |

---

## Smart Home

| Device | Location | Status | Protocol | Current Control |
|--------|----------|--------|----------|-----------------|
| Plejd connector | Home | Owned | Bluetooth | Plejd app only |
| Plejd lighting | Home | Planned | Bluetooth/Mesh | Will use Plejd app |

### Plejd Notes
- Swedish smart lighting system
- Uses Bluetooth mesh networking
- Currently requires Plejd app for control
- Integration options to explore:
  - Home Assistant integration
  - Direct Bluetooth control from Linux
  - Bridge device for network control

---

## Ecosystem Summary

```
┌─────────────────────────────────────────────────────────┐
│                    LifeOps Ecosystems                   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
│  │  Apple  │  │ Google  │  │ Samsung │  │  Linux  │   │
│  ├─────────┤  ├─────────┤  ├─────────┤  ├─────────┤   │
│  │ iPhone  │  │ Bathroom│  │ TVs     │  │ 3x PCs  │   │
│  │ iPad    │  │ Speaker │  │ Speakers│  │ Rasp Pi │   │
│  │ Mac     │  │         │  │         │  │         │   │
│  │ HomePod │  │         │  │         │  │         │   │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘   │
│                                                         │
│  ┌─────────┐  ┌─────────┐                              │
│  │  Plejd  │  │  Oura   │                              │
│  ├─────────┤  ├─────────┤                              │
│  │ Lighting│  │  Ring   │                              │
│  │ (BT)    │  │ (Health)│                              │
│  └─────────┘  └─────────┘                              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Integration Challenges

1. **Apple ecosystem** - Relatively closed, best controlled via HomeKit or Shortcuts
2. **Google Home** - Has API access, integrates with many services
3. **Samsung** - SmartThings platform, varying API support
4. **Plejd** - Bluetooth-only by default, may need bridge solution
5. **Oura** - Good API access, data sync frequency considerations
6. **Cross-location** - Devices at cabins need remote access consideration

---

## Future Devices

*Space for planned additions*

| Device | Location | Purpose | Priority |
|--------|----------|---------|----------|
| | | | |

---

*Last updated: January 2025*
