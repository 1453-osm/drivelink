# DriveLink — Turkey Offline Pack Build

Builds the three-file Turkey offline package consumed by the DriveLink app:

| File | Purpose | Approx. size |
|---|---|---|
| `turkey.pmtiles` | Vector tiles (Protomaps basemaps v4 schema) | 300-500 MB |
| `turkey.ghz` | GraphHopper routing graph (car profile) | 80-200 MB |
| `turkey_addresses.db` | SQLite FTS5 address + POI index | 50-150 MB |
| `manifest.json` | Version, SHA-256 hashes, URLs | <1 KB |

The pack is published as a **GitHub Release** on the repo; the app downloads
it at runtime via [`TurkeyPackageService`](../../lib/core/services/turkey_package_service.dart).

## Prerequisites

Install once on the build machine (Linux or macOS recommended, Windows with WSL):

### System packages

```bash
# Ubuntu / Debian
sudo apt install -y openjdk-21-jre python3 python3-pip sqlite3 osmium-tool curl

# macOS (Homebrew)
brew install openjdk@21 python@3.11 sqlite osmium-tool
```

### External JARs / tools (download once)

Put the files listed below under `tools/build_turkey_pack/bin/`.

1. **Protomaps basemaps planetiler** — builds the pmtiles.
   Download the latest `protomaps-basemaps.jar` from
   https://github.com/protomaps/basemaps/releases
   (or build locally with `mvn -f tiles/pom.xml package`).

2. **GraphHopper** — builds the routing graph.
   Download `graphhopper-web-X.X.jar` from
   https://github.com/graphhopper/graphhopper/releases
   (version 9.x or later).

3. **pmtiles CLI** (optional, only if you prefer planet extract over self-build):
   https://github.com/protomaps/go-pmtiles/releases

Final layout:

```
tools/build_turkey_pack/
  bin/
    protomaps-basemaps.jar
    graphhopper-web-9.1.jar
    pmtiles          # (optional, if extracting from planet)
  build.py
  config.yaml
  extract_addresses.py
  README.md
```

### Python deps

```bash
pip install -r tools/build_turkey_pack/requirements.txt
```

## Usage

```bash
cd tools/build_turkey_pack
python build.py --version 2026-04-17
```

### Flags

| Flag | Default | Meaning |
|---|---|---|
| `--version` | (required) | Release version tag (e.g. `2026-04-17`) |
| `--config` | `config.yaml` | Alternative config path |
| `--skip-download` | off | Reuse cached Turkey `.osm.pbf` |
| `--skip-pmtiles` | off | Skip pmtiles build (reuse last) |
| `--skip-graph` | off | Skip routing graph build |
| `--skip-addresses` | off | Skip addresses DB build |
| `--base-url` | (from config) | Public base URL for the release assets (for manifest) |

### Output

After a full build:

```
tools/build_turkey_pack/output/
  turkey-2026-04-17/
    turkey.pmtiles
    turkey.ghz
    turkey_addresses.db
    manifest.json
    SHA256SUMS.txt
```

### Resource budget

| Stage | Time (modern laptop) | Peak RAM | Disk |
|---|---|---|---|
| Download `turkey-latest.osm.pbf` | 1-5 min (~700 MB) | <500 MB | 700 MB |
| Build pmtiles (planetiler) | 10-30 min | 4-8 GB | ~1 GB tmp |
| Build routing graph (GraphHopper) | 10-40 min | 6-12 GB | ~500 MB tmp |
| Extract addresses | 3-10 min | <1 GB | <200 MB tmp |
| **Total** | **30-90 min** | **8-12 GB** | **~3 GB** |

## Publishing a release

After a successful build:

```bash
gh release create turkey-pack-<version> \
  output/turkey-<version>/turkey.pmtiles \
  output/turkey-<version>/turkey.ghz \
  output/turkey-<version>/turkey_addresses.db \
  output/turkey-<version>/manifest.json \
  --title "Turkey Offline Pack <version>" \
  --notes-file output/turkey-<version>/RELEASE_NOTES.md
```

The app fetches `manifest.json` from the **latest release** via:

```
https://github.com/1453-osm/drivelink/releases/latest/download/manifest.json
```

Make sure `manifest.json`'s `url` fields point to the same release's asset URLs.

## Updating the pack

Run the build monthly (or as needed) to track upstream OpenStreetMap changes.
Increment `--version` (we use `YYYY-MM-DD` format). The app detects version
mismatch via the stored manifest and offers a re-download.
