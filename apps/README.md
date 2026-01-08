# LifeOps Frontend Apps

Device-specific frontend applications for LifeOps.

## Architecture

Each platform has its own repository for independent development and deployment:

```
apps/
├── ios/          # iOS + watchOS (SwiftUI)
├── android/      # Android (Kotlin/Jetpack Compose) - planned
├── web/          # Web dashboard (React) - planned
└── README.md     # This file
```

## Available Apps

### iOS + watchOS
- **Location**: `apps/ios/`
- **Tech**: Native SwiftUI
- **Platforms**: iPhone (iOS 17+), Apple Watch (watchOS 10+)
- **Status**: In development

Features:
- Rolling timeline/todo view
- Complete, postpone, skip actions
- Streak tracking and XP rewards
- Apple Watch companion for quick actions

### Android (Planned)
- **Location**: `apps/android/`
- **Tech**: Kotlin + Jetpack Compose
- **Platforms**: Android phones, Wear OS

### Web Dashboard (Planned)
- **Location**: `apps/web/`
- **Tech**: React + Vite + shadcn/ui
- **Platforms**: Desktop browsers

## Development

Each app connects to the LifeOps API backend:

```
Production: https://your-domain/api
Development: http://localhost:8000
```

### Running the Backend

```bash
# From main LifeOps directory
docker-compose up -d lifeops-api stats-api
```

### API Documentation

- Swagger UI: http://localhost:8000/docs
- OpenAPI spec: http://localhost:8000/openapi.json

## Repository Management

Each app is a separate git repository for:
- Independent versioning
- Platform-specific CI/CD
- Separate release cycles
- Team isolation (if needed)

To clone all repos:
```bash
# Main backend
git clone https://github.com/your-user/lifeops.git

# iOS app
git clone https://github.com/your-user/lifeops-ios.git lifeops/apps/ios

# Android app (when available)
git clone https://github.com/your-user/lifeops-android.git lifeops/apps/android
```
