# CLAUDE.md - LifeOps iOS App Guide

This file provides guidance to Claude Code when working on the LifeOps iOS project.

## Project Overview

**LifeOps iOS** is the native SwiftUI companion app for the LifeOps personal life management system. It provides iOS, watchOS, and widget interfaces for interacting with the LifeOps backend API.

## Related Projects

| Project | Location | Purpose |
|---------|----------|---------|
| **LifeOps Backend** | `../LifeOps/` | FastAPI backend, database, gamification engine |
| **LifeOps iOS** | This project | Native iOS/watchOS/Widget apps |

## API Connection

The iOS app connects to the LifeOps FastAPI backend:

| Environment | Base URL | Notes |
|-------------|----------|-------|
| Simulator | `http://localhost:8000` | Default for development |
| Real Device | Configurable via Settings | Default: `http://192.168.1.100:8000` |

### API Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/auth/login` | POST | User authentication |
| `/timeline` | GET | Get rolling timeline feed |
| `/timeline/day` | GET | Get full day timeline |
| `/timeline/items` | GET | List all timeline items |
| `/timeline/items` | POST | Create new timeline item |
| `/timeline/anchors` | GET | Get time anchors |
| `/timeline/{code}/complete` | POST | Complete an item |
| `/timeline/{code}/postpone` | POST | Postpone an item |
| `/timeline/{code}/skip` | POST | Skip an item |

### Authentication

- Uses JWT Bearer tokens stored in `UserDefaults`
- Access token: `access_token` key
- Refresh token: `refresh_token` key

## Project Structure

```
lifeops-ios/
├── LifeOps/                    # iOS App Target
│   └── LifeOpsApp.swift
├── LifeOpsWatch/               # watchOS App Target
│   ├── LifeOpsWatchApp.swift
│   └── WatchTimelineView.swift
├── LifeOpsWidget/              # Widget Extension
│   ├── LifeOpsWidget.swift
│   └── WidgetAPIClient.swift
├── Shared/                     # Shared Code (iOS + Watch)
│   ├── Models/
│   │   └── TimelineModels.swift
│   ├── Services/
│   │   └── APIClient.swift
│   └── Views/
│       ├── TimelineView.swift
│       ├── TimelineViewModel.swift
│       └── ItemDetailSheet.swift
├── SETUP.md                    # Xcode setup instructions
└── README.md
```

## Key Files

| File | Purpose |
|------|---------|
| `Shared/Services/APIClient.swift` | Main API client with all backend calls |
| `Shared/Models/TimelineModels.swift` | Data models matching backend schemas |
| `Shared/Views/TimelineView.swift` | Main timeline UI |
| `LifeOpsWidget/WidgetAPIClient.swift` | Simplified widget-specific API client |

## Development Requirements

- macOS 14+ (Sonoma)
- Xcode 15+
- iOS 17+ / watchOS 10+
- Apple Developer account (for device testing)

## Running the App

### Prerequisites

1. **Start the LifeOps backend:**
   ```bash
   cd ../LifeOps
   docker-compose up -d lifeops-api
   ```

2. **Verify backend is running:**
   ```bash
   curl http://localhost:8000/health
   ```

### Simulator

1. Open `LifeOps.xcodeproj` in Xcode
2. Select `LifeOps` scheme
3. Choose an iPhone simulator
4. Press ⌘R to run

### Real Device

1. Find your Mac's local IP: `ifconfig | grep inet`
2. Update API URL in Settings within the app (or modify `APIClient.swift`)
3. Ensure device is on same WiFi network as Mac

## Data Models

The iOS models must match the backend Pydantic schemas:

| iOS Model | Backend Schema | File |
|-----------|----------------|------|
| `TimelineFeed` | `TimelineFeed` | `TimelineModels.swift` |
| `TimelineItem` | `TimelineItem` | `TimelineModels.swift` |
| `TimeAnchor` | `TimeAnchor` | `TimelineModels.swift` |
| `CompleteResponse` | `CompleteResponse` | `TimelineModels.swift` |
| `PostponeResponse` | `PostponeResponse` | `TimelineModels.swift` |

## Syncing with Backend

When backend API changes:
1. Update `TimelineModels.swift` to match new schemas
2. Update `APIClient.swift` for new/changed endpoints
3. Update widget API client if affected

## Features

### iOS App
- Rolling timeline/todo view
- Complete, postpone, skip actions
- Streak tracking display
- XP rewards feedback

### Watch App
- Quick timeline view
- One-tap complete
- Quick postpone

### Widgets
- Small: Next item with streak
- Medium: Up to 3 items
- Large: Full timeline (6 items)
- Lock Screen: Circular, rectangular, inline

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cannot connect to server | Check backend is running: `curl http://localhost:8000/health` |
| Unauthorized errors | Token expired - logout and login again |
| Watch not syncing | Ensure iPhone app running, same network |
| Real device can't connect | Check firewall allows port 8000, same WiFi |
