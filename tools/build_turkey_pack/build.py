#!/usr/bin/env python3
"""
DriveLink — Turkey Offline Pack build script.

Orchestrates:
  1. Geofabrik Turkey PBF download
  2. pmtiles build (Protomaps basemaps v4 via planetiler)
  3. GraphHopper routing graph build
  4. Addresses SQLite (FTS5) extraction
  5. manifest.json generation with SHA-256 hashes

See README.md for prerequisites and usage.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml  # type: ignore
    from tqdm import tqdm  # type: ignore
except ImportError:
    print("ERROR: install deps first: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)


HERE = Path(__file__).resolve().parent


@dataclass
class BuildContext:
    config: dict
    version: str
    output_dir: Path
    cache_dir: Path
    release_dir: Path
    args: argparse.Namespace

    @property
    def pbf_path(self) -> Path:
        return self.cache_dir / "turkey-latest.osm.pbf"

    @property
    def pmtiles_path(self) -> Path:
        return self.release_dir / "turkey.pmtiles"

    @property
    def graph_path(self) -> Path:
        return self.release_dir / "turkey.ghz"

    @property
    def addresses_path(self) -> Path:
        return self.release_dir / "turkey_addresses.db"

    @property
    def manifest_path(self) -> Path:
        return self.release_dir / "manifest.json"


# ─── Utilities ──────────────────────────────────────────────────────────

def log(msg: str) -> None:
    ts = datetime.now().strftime("%H:%M:%S")
    print(f"[{ts}] {msg}", flush=True)


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def run(cmd: list[str], *, cwd: Path | None = None) -> None:
    log(f"$ {' '.join(str(c) for c in cmd)}")
    result = subprocess.run(cmd, cwd=cwd, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed (exit {result.returncode}): {cmd[0]}")


def require_tool(name: str, cmd: str) -> None:
    if shutil.which(cmd) is None:
        raise RuntimeError(f"Required tool '{name}' not found on PATH: {cmd}")


def require_file(label: str, path: Path) -> None:
    if not path.exists():
        raise RuntimeError(f"Required {label} not found: {path}")


# ─── Stages ─────────────────────────────────────────────────────────────

def download_pbf(ctx: BuildContext) -> None:
    dst = ctx.pbf_path
    if ctx.args.skip_download and dst.exists():
        log(f"Skipping download (reusing {dst.name}, {dst.stat().st_size // (1<<20)} MB)")
        return

    url = ctx.config["source"]["pbf_url"]
    log(f"Downloading {url}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    tmp = dst.with_suffix(".part")

    with urllib.request.urlopen(url) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        with open(tmp, "wb") as out, tqdm(
            total=total,
            unit="B",
            unit_scale=True,
            unit_divisor=1024,
            desc="turkey-latest.osm.pbf",
        ) as bar:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                out.write(chunk)
                bar.update(len(chunk))

    tmp.replace(dst)
    log(f"Downloaded: {dst} ({dst.stat().st_size // (1<<20)} MB)")


def build_pmtiles(ctx: BuildContext) -> None:
    if ctx.args.skip_pmtiles and ctx.pmtiles_path.exists():
        log(f"Skipping pmtiles build (reusing existing {ctx.pmtiles_path.name})")
        return

    tools = ctx.config["tools"]
    jar = HERE / tools["protomaps_jar"]
    require_file("Protomaps basemaps JAR", jar)
    require_tool("java", tools["java"])

    heap = ctx.config["pmtiles"]["java_heap"]
    max_z = ctx.config["pmtiles"]["max_zoom"]
    min_z = ctx.config["pmtiles"]["min_zoom"]

    ctx.pmtiles_path.parent.mkdir(parents=True, exist_ok=True)

    # Protomaps basemaps CLI uses key=value flags (Planetiler-style).
    # - --download: fetch Natural Earth, water/land polygons, etc.
    # - --osm_path: local OSM PBF (we already downloaded Turkey above)
    # - --output: PMTiles destination
    # - --force: overwrite existing output
    # We don't supply a landcover path → the landcover layer is skipped
    # (Daylight landcover is multi-GB and doesn't fit GitHub runner disk).
    cmd = [
        tools["java"],
        f"-Xmx{heap}",
        "-jar", str(jar),
        "--download",
        f"--osm_path={ctx.pbf_path}",
        f"--output={ctx.pmtiles_path}",
        f"--minzoom={min_z}",
        f"--maxzoom={max_z}",
        "--force",
    ]
    run(cmd)

    if not ctx.pmtiles_path.exists():
        raise RuntimeError("pmtiles build did not produce an output file")
    log(f"pmtiles ready: {ctx.pmtiles_path} "
        f"({ctx.pmtiles_path.stat().st_size // (1<<20)} MB)")


def build_graph(ctx: BuildContext) -> None:
    if ctx.args.skip_graph and ctx.graph_path.exists():
        log(f"Skipping graph build (reusing existing {ctx.graph_path.name})")
        return

    tools = ctx.config["tools"]
    jar = HERE / tools["graphhopper_jar"]
    require_file("GraphHopper JAR", jar)
    require_tool("java", tools["java"])

    heap = ctx.config["graph"]["java_heap"]
    cache = ctx.cache_dir / ctx.config["graph"]["cache_dir"]
    if cache.exists():
        shutil.rmtree(cache)
    cache.mkdir(parents=True)

    # Write a minimal GraphHopper config.
    gh_config = cache.parent / "graphhopper.yml"
    gh_config.write_text(_graphhopper_config_yaml(ctx, cache), encoding="utf-8")

    # GraphHopper 9.x `import` subcommand takes the config YAML as a
    # positional argument (the PBF path lives inside it as datareader.file).
    #   java -jar graphhopper-web.jar import graphhopper.yml
    cmd = [
        tools["java"],
        f"-Xmx{heap}",
        "-jar", str(jar),
        "import",
        str(gh_config),
    ]
    run(cmd)

    # Package the graph folder into a single zip archive (.ghz).
    log(f"Packaging graph into {ctx.graph_path}")
    ctx.graph_path.parent.mkdir(parents=True, exist_ok=True)
    if ctx.graph_path.exists():
        ctx.graph_path.unlink()
    # Build a zip (shutil.make_archive adds .zip; rename afterwards).
    tmp_base = str(ctx.graph_path.with_suffix(""))
    archive = shutil.make_archive(tmp_base, "zip", cache)
    Path(archive).rename(ctx.graph_path)
    log(f"Graph archive ready: {ctx.graph_path} "
        f"({ctx.graph_path.stat().st_size // (1<<20)} MB)")


def _graphhopper_config_yaml(ctx: BuildContext, cache: Path) -> str:
    # GraphHopper 9.x: profiles use custom_model instead of the old
    # (vehicle, weighting) pair. A minimal inline model mimicking the
    # classic "car/fastest" behaviour is good enough as a default.
    profiles_yaml = "\n".join(
        (
            f"    - name: {p['name']}\n"
            f"      custom_model:\n"
            f"        priority:\n"
            f"          - if: 'road_class == MOTORWAY'\n"
            f"            multiply_by: 1.0\n"
            f"        speed:\n"
            f"          - if: 'true'\n"
            f"            limit_to: 'car_average_speed'\n"
        )
        for p in ctx.config["graph"]["profiles"]
    )
    return (
        "graphhopper:\n"
        f"  datareader.file: {ctx.pbf_path}\n"
        f"  graph.location: {cache}\n"
        "  import.osm.ignored_highways: footway,cycleway,path,pedestrian,steps\n"
        "  profiles:\n"
        f"{profiles_yaml}\n"
        "  profiles_ch:\n"
        + "\n".join(f"    - profile: {p['name']}" for p in ctx.config["graph"]["profiles"])
        + "\n"
    )


def build_addresses(ctx: BuildContext) -> None:
    if ctx.args.skip_addresses and ctx.addresses_path.exists():
        log(f"Skipping addresses build (reusing existing {ctx.addresses_path.name})")
        return

    script = HERE / "extract_addresses.py"
    require_file("extract_addresses.py", script)
    tools = ctx.config["tools"]
    require_tool("osmium", tools["osmium"])

    ctx.addresses_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        str(script),
        "--pbf", str(ctx.pbf_path),
        "--output", str(ctx.addresses_path),
        "--config", str(HERE / "config.yaml"),
        "--osmium", tools["osmium"],
    ]
    run(cmd)

    if not ctx.addresses_path.exists():
        raise RuntimeError("addresses DB build did not produce an output file")
    log(f"Addresses ready: {ctx.addresses_path} "
        f"({ctx.addresses_path.stat().st_size // (1<<20)} MB)")


def write_manifest(ctx: BuildContext) -> None:
    base_url_tpl = ctx.args.base_url or ctx.config["release"]["asset_base_url"]
    base_url = base_url_tpl.format(version=ctx.version).rstrip("/")

    def asset_entry(path: Path) -> dict:
        return {
            "filename": path.name,
            "url": f"{base_url}/{path.name}",
            "size": path.stat().st_size,
            "sha256": sha256_of(path),
        }

    manifest = {
        "version": ctx.version,
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "assets": {
            "pmtiles": asset_entry(ctx.pmtiles_path),
            "graph": asset_entry(ctx.graph_path),
            "addresses": asset_entry(ctx.addresses_path),
        },
    }

    ctx.manifest_path.write_text(
        json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8"
    )
    log(f"Manifest written: {ctx.manifest_path}")

    # Also emit a simple SHA256SUMS.txt for human verification.
    sums = ctx.release_dir / "SHA256SUMS.txt"
    lines = [
        f"{manifest['assets'][k]['sha256']}  {manifest['assets'][k]['filename']}"
        for k in ("pmtiles", "graph", "addresses")
    ]
    sums.write_text("\n".join(lines) + "\n", encoding="utf-8")


def print_release_hint(ctx: BuildContext) -> None:
    log("")
    log("Build complete. Release with:")
    log("")
    print(
        f"  gh release create turkey-pack-{ctx.version} \\\n"
        f"    {ctx.pmtiles_path} \\\n"
        f"    {ctx.graph_path} \\\n"
        f"    {ctx.addresses_path} \\\n"
        f"    {ctx.manifest_path} \\\n"
        f"    --title 'Turkey Offline Pack {ctx.version}' \\\n"
        f"    --notes 'Auto-built {ctx.version}'\n"
    )


# ─── Main ───────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description="Build Turkey offline pack")
    parser.add_argument("--version", required=True, help="Release version tag, e.g. 2026-04-17")
    parser.add_argument("--config", default=str(HERE / "config.yaml"))
    parser.add_argument("--skip-download", action="store_true")
    parser.add_argument("--skip-pmtiles", action="store_true")
    parser.add_argument("--skip-graph", action="store_true")
    parser.add_argument("--skip-addresses", action="store_true")
    parser.add_argument("--base-url", default=None,
                        help="Override release.asset_base_url from config")
    args = parser.parse_args()

    with open(args.config, encoding="utf-8") as f:
        config = yaml.safe_load(f)

    output_dir = HERE / "output"
    cache_dir = output_dir / "cache"
    release_dir = output_dir / f"turkey-{args.version}"
    for d in (output_dir, cache_dir, release_dir):
        d.mkdir(parents=True, exist_ok=True)

    ctx = BuildContext(
        config=config,
        version=args.version,
        output_dir=output_dir,
        cache_dir=cache_dir,
        release_dir=release_dir,
        args=args,
    )

    try:
        download_pbf(ctx)
        build_pmtiles(ctx)
        build_graph(ctx)
        build_addresses(ctx)
        write_manifest(ctx)
        print_release_hint(ctx)
    except Exception as e:
        log(f"BUILD FAILED: {e}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
