# LifeOps iOS App - Xcode Setup

This guide explains how to set up the Xcode project for the LifeOps iOS and watchOS apps.

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+
- Apple Developer account (for device testing)

## Create Xcode Project

Since the Swift files are created but not the Xcode project file, follow these steps:

### 1. Create New Project

1. Open Xcode
2. File > New > Project
3. Choose **App** under iOS
4. Settings:
   - Product Name: `LifeOps`
   - Team: Your Apple ID
   - Organization Identifier: `com.yourname.lifeops`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None** (we handle data via API)
   - ✅ Include Tests

### 2. Add Watch Target

1. File > New > Target
2. Choose **App** under watchOS
3. Settings:
   - Product Name: `LifeOpsWatch`
   - Embed in Companion: `LifeOps`
   - Interface: **SwiftUI**

### 3. Import Source Files

Replace the generated files with the ones in this repository:

```
# iOS App
LifeOps/
  ├── LifeOpsApp.swift         (main app entry)

# Watch App
LifeOpsWatch/
  ├── LifeOpsWatchApp.swift    (watch entry)
  └── WatchTimelineView.swift  (watch UI)

# Shared Code (add to both targets)
Shared/
  ├── Models/
  │   └── TimelineModels.swift
  ├── Services/
  │   └── APIClient.swift
  └── Views/
      ├── TimelineView.swift
      ├── TimelineViewModel.swift
      └── ItemDetailSheet.swift
```

### 4. Configure Shared Code

1. Select each file in `Shared/`
2. In the File Inspector (right panel)
3. Under "Target Membership", check both:
   - ✅ LifeOps
   - ✅ LifeOpsWatch

### 5. Configure API URL

For simulator testing, the default `localhost:8000` works.

For real device:
1. Find your Mac's local IP: `ifconfig | grep inet`
2. Update in `APIClient.swift` or Settings within the app

## Project Structure

```
LifeOps.xcodeproj/
├── LifeOps/                    # iOS App Target
│   ├── LifeOpsApp.swift
│   └── Assets.xcassets
├── LifeOpsWatch/               # watchOS App Target
│   ├── LifeOpsWatchApp.swift
│   ├── WatchTimelineView.swift
│   └── Assets.xcassets
├── Shared/                     # Shared Code
│   ├── Models/
│   ├── Services/
│   └── Views/
└── LifeOpsTests/              # Tests
```

## Running the App

### Simulator
1. Select `LifeOps` scheme
2. Choose an iPhone simulator
3. Press ⌘R to run

### Watch Simulator
1. In the iOS simulator, go to Settings > Developer
2. Enable "Connect to Watch Simulator"
3. Select `LifeOpsWatch` scheme
4. Choose a Watch simulator paired with iPhone
5. Press ⌘R to run

### Real Device
1. Connect iPhone via USB
2. Trust the computer on iPhone
3. Select your device in scheme
4. Press ⌘R to run (may need to trust developer in Settings)

## API Connection

The app connects to your LifeOps backend at:
- Simulator: `http://localhost:8000`
- Device: Configure in Settings

Make sure the backend is running:
```bash
cd /path/to/LifeOps
docker-compose up -d lifeops-api
```

## Features

### iOS App
- **Timeline View**: Rolling list of todos/tasks
- **Item Actions**: Complete, postpone, skip
- **Streak Tracking**: Visual streak indicators
- **XP Rewards**: Gamification feedback

### Watch App
- **Quick Timeline**: Most urgent items
- **One-tap Complete**: Fast task completion
- **Quick Postpone**: Defer to later

## Troubleshooting

### "Cannot connect to server"
- Check backend is running: `curl http://localhost:8000/health`
- For real device, ensure same WiFi network
- Check firewall allows port 8000

### "Unauthorized"
- Token may have expired
- Logout and login again

### Watch app not syncing
- Ensure iPhone app is running
- Check Watch and iPhone on same network
