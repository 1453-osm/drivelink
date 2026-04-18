# DriveLink -- Claude Code Instructions

## Project
Flutter car infotainment app. Android only.
Open-source under GPLv3.

## Tech Stack
- Flutter 3.x, Dart (min SDK 3.10)
- State: Riverpod
- Navigation: GoRouter
- Database: Drift (app state) + raw sqlite3 (offline address FTS5 index)
- Map renderer: `maplibre_gl` ^0.25.0 (native MapLibre 12.3 with PMTiles support)
- Offline routing: GraphHopper 9.1 via Kotlin MethodChannel (`drivelink/graphhopper`)
- USB: `usb_serial`
- Audio: `just_audio` + `audio_service`
- Archive: `archive` (unpacks the .ghz routing graph)
- Hashing: `crypto` (SHA-256 verify of pack assets)

## Architecture
```
lib/
  app/            — app.dart, router.dart, theme/
  core/
    database/     — Drift schema, settings/trip repositories, addresses_db.dart (FTS5)
    services/     — USB serial, location, audio, TTS, trip, steering, permissions,
                    map_asset_manager.dart, turkey_package_service.dart,
                    region_coverage_service.dart
    constants/    — app constants, vehicle profiles
    utils/        — Dart extensions
  features/
    dashboard/    — main screen, gauges, mini map, media controls
    navigation/
      data/
        map_style_loader.dart — runtime placeholder injection for style JSON
        datasources/
          graphhopper_source.dart       — platform-channel wrapper (offline)
          local_geocoding_source.dart   — SQLite FTS5 address search
          local_poi_source.dart         — SQLite radius + FTS POI lookup
      presentation/ — map screen, search screen, widgets
    obd/          — ELM327, PID parsing, DTC, OBD dashboard
    vehicle_bus/  — ESP32, VAN/CAN parsing, bus monitor
    media/        — music player, playlist, volume
    settings/     — vehicle config, USB config, theme,
                    map_download_screen.dart (single Turkey pack UI)
    trip_computer/ — trip stats, fuel economy, trip history
  shared/         — reusable widgets
android/
  app/src/main/kotlin/com/drivelink/drivelink/
    MainActivity.kt
    GraphHopperBridge.kt — MethodChannel handler for load/route/close
tools/
  drivelink_basemap/       — Maven project: custom minimal Planetiler profile
    src/main/java/com/drivelink/basemap/*.java
    pom.xml
  build_turkey_pack/       — Python orchestrator for the offline pack
    build.py, extract_addresses.py, config.yaml, requirements.txt
assets/
  map/
    dark_style.json / light_style.json — style templates with
                                         {{TILE_URL}} / {{GLYPHS_URL}} / {{SPRITE_URL}} placeholders
    glyphs/    — Noto Sans Regular/Medium/Italic × 0-511 range (PBF)
    sprite/    — Protomaps v4 sprites (dark / light, 1x / 2x)
  geo/
    turkey.geojson — Turkey polygon overlay drawn on the map
.github/workflows/
  build-turkey-pack.yml — builds and publishes the pack as a GitHub Release
```

## Offline Pack Pipeline

The app downloads a single ~1.4 GB pack from GitHub Releases at runtime:

| File | Purpose | Size |
|---|---|---|
| `turkey.pmtiles` | Vector tiles (custom Planetiler profile + Natural Earth ocean/lakes) | ~1.0 GB |
| `turkey.ghz` | GraphHopper routing graph (car profile, CH prepared) | ~360 MB |
| `turkey_addresses.db` | SQLite FTS5 index of places + POIs | ~14 MB |
| `manifest.json` | version, SHA-256 hashes, asset URLs | <1 KB |

### Publishing a new release
Trigger the `Build Turkey Pack` workflow (Actions tab) with a version tag:
```bash
gh workflow run build-turkey-pack.yml -f version=YYYY-MM-DD
```
Runs on `ubuntu-latest`, ~30–45 min end-to-end. The app fetches
`releases/latest/download/manifest.json` via `TurkeyPackageService.fetchManifest`,
then streams each asset with SHA-256 verification.

### Build stages (run by `tools/build_turkey_pack/build.py`)
1. Download `turkey-latest.osm.pbf` from Geofabrik
2. Run `drivelink-basemap.jar` (our minimal Planetiler profile) → pmtiles
3. Run `graphhopper-web-9.1.jar import` → graph directory, zipped to `.ghz`
4. `osmium tags-filter` + Python → `turkey_addresses.db` (FTS5)
5. Compute SHA-256 for each asset, emit `manifest.json` + `SHA256SUMS.txt`

No OSM coastline shapefiles or Daylight landcover data are required — the
profile relies on OSM's own water features plus Natural Earth ocean/lakes.

## Commands
- `flutter pub get`
- `dart run build_runner build` (for Drift codegen)
- `flutter analyze`
- `flutter build apk --debug` / `--release`
- `gh workflow run build-turkey-pack.yml -f version=YYYY-MM-DD` (publish pack)

## Key Decisions
- Dark theme default (car night use)
- Fully offline navigation — internet is only used to download the Turkey pack
- Single-pack model (country-wide) — no region tree, no bbox rectangles
- MapLibre loads a local style string; all URLs (tiles, glyphs, sprite) are
  `file://` / `pmtiles://file://` paths resolved at runtime
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
- `context.push()` for sub-screens (hardware back button works)
- Portrait + landscape support (phone + tablet/head-unit)
- Commit messages in English with conventional commits (`feat:`, `fix:`, `docs:`)
