# DriveLink -- Claude Code Instructions

## Project
Flutter car infotainment app. Android only.
Open-source under GPLv3.

## Tech Stack
- Flutter 3.x, Dart
- State: Riverpod
- Navigation: GoRouter
- Database: Drift (SQLite)
- Map: flutter_map + FMTC
- USB: usb_serial
- Audio: just_audio + audio_service

## Architecture
```
lib/
  app/            — app.dart, router.dart, theme/
  core/
    database/     — Drift schema, settings/trip repositories
    services/     — USB serial, location, audio, TTS, trip, steering, permissions
    constants/    — app constants, vehicle profiles
    utils/        — Dart extensions
  features/
    dashboard/    — main screen, gauges, mini map, media controls
    navigation/   — offline map, routing, address search, turn-by-turn
    obd/          — ELM327, PID parsing, DTC, OBD dashboard
    vehicle_bus/  — ESP32, VAN/CAN parsing, bus monitor
    media/        — music player, playlist, volume
    settings/     — vehicle config, USB config, theme, map download
    trip_computer/ — trip stats, fuel economy, trip history
  shared/         — reusable widgets
```

## Commands
- flutter pub get
- dart run build_runner build (for Drift codegen)
- flutter analyze
- flutter build apk --release

## Key Decisions
- Dark theme default (car night use)
- Offline-first (maps, routing)
- USB serial for ESP32 (VAN bus) + ELM327 (OBD-II)
- Turkish UI language
- Android only (no iOS/web/desktop)

## Supported Vehicles
- Peugeot 206/307 (VAN bus via ESP32)
- Peugeot 407 (CAN bus via ESP32)
- Citroen C3 (VAN bus), C4 (CAN bus)
- Any OBD-II vehicle via ELM327 USB

## USB Protocol
- ESP32: 115200 baud, JSON lines over serial
- ELM327: 38400 baud, AT commands, PID queries at 200ms intervals

## Conventions
- Feature-based modular structure
- Turkish user-facing strings
- context.push() for sub-screens (hardware back button works)
- Portrait + landscape support (phone + tablet/head-unit)
- Commit messages in English with conventional commits (feat:, fix:, docs:)
