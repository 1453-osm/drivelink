#!/usr/bin/env python3
"""
Extract place names and POI index from a Turkey OSM PBF into a SQLite
FTS5 database consumable by the DriveLink app's offline geocoder.

Output schema:

  CREATE TABLE places (
    id INTEGER PRIMARY KEY,
    osm_id TEXT,
    kind TEXT,         -- 'city' | 'town' | 'village' | 'suburb' | 'neighbourhood'
    name TEXT,         -- Primary name (name:tr preferred, falls back to name)
    admin TEXT,        -- Parent admin name (e.g. province for a village)
    lat REAL,
    lon REAL
  );

  CREATE TABLE pois (
    id INTEGER PRIMARY KEY,
    osm_id TEXT,
    category TEXT,     -- 'fuel' | 'parking' | 'hospital' | ...
    name TEXT,
    admin TEXT,
    lat REAL,
    lon REAL
  );

  CREATE VIRTUAL TABLE places_fts USING fts5(name, admin, content='places', content_rowid='id');
  CREATE VIRTUAL TABLE pois_fts USING fts5(name, admin, category, content='pois', content_rowid='id');
"""
from __future__ import annotations

import argparse
import json
import sqlite3
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:
    print("ERROR: install deps first: pip install -r requirements.txt", file=sys.stderr)
    sys.exit(1)


def run(cmd: list[str]) -> None:
    print(f"$ {' '.join(cmd)}", flush=True)
    r = subprocess.run(cmd, check=False)
    if r.returncode != 0:
        raise RuntimeError(f"Command failed ({r.returncode}): {cmd[0]}")


def pick_name(tags: dict) -> str | None:
    for k in ("name:tr", "name", "int_name", "name:en"):
        v = tags.get(k)
        if v and v.strip():
            return v.strip()
    return None


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS places (
            id INTEGER PRIMARY KEY,
            osm_id TEXT,
            kind TEXT,
            name TEXT,
            admin TEXT,
            lat REAL,
            lon REAL
        );
        CREATE TABLE IF NOT EXISTS pois (
            id INTEGER PRIMARY KEY,
            osm_id TEXT,
            category TEXT,
            name TEXT,
            admin TEXT,
            lat REAL,
            lon REAL
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS places_fts USING fts5(
            name, admin, content='places', content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );
        CREATE VIRTUAL TABLE IF NOT EXISTS pois_fts USING fts5(
            name, admin, category, content='pois', content_rowid='id',
            tokenize='unicode61 remove_diacritics 2'
        );
        CREATE INDEX IF NOT EXISTS idx_places_kind ON places(kind);
        CREATE INDEX IF NOT EXISTS idx_pois_category ON pois(category);
    """)


def insert_place(cur: sqlite3.Cursor, row: dict) -> None:
    cur.execute(
        "INSERT INTO places (osm_id, kind, name, admin, lat, lon) VALUES (?, ?, ?, ?, ?, ?)",
        (row["osm_id"], row["kind"], row["name"], row.get("admin"), row["lat"], row["lon"]),
    )
    rid = cur.lastrowid
    cur.execute(
        "INSERT INTO places_fts(rowid, name, admin) VALUES (?, ?, ?)",
        (rid, row["name"], row.get("admin") or ""),
    )


def insert_poi(cur: sqlite3.Cursor, row: dict) -> None:
    cur.execute(
        "INSERT INTO pois (osm_id, category, name, admin, lat, lon) VALUES (?, ?, ?, ?, ?, ?)",
        (row["osm_id"], row["category"], row["name"], row.get("admin"), row["lat"], row["lon"]),
    )
    rid = cur.lastrowid
    cur.execute(
        "INSERT INTO pois_fts(rowid, name, admin, category) VALUES (?, ?, ?, ?)",
        (rid, row["name"], row.get("admin") or "", row["category"]),
    )


def extract(
    pbf: Path,
    output: Path,
    config: dict,
    osmium: str,
) -> None:
    place_types: list[str] = config["addresses"]["place_types"]
    amenities: list[str] = config["addresses"]["amenities"]

    with tempfile.TemporaryDirectory(prefix="dl-addr-") as tmpdir_str:
        tmp = Path(tmpdir_str)

        # Step 1 — filter PBF to only the tags we care about.
        filtered_pbf = tmp / "filtered.osm.pbf"
        filter_args = [
            osmium, "tags-filter", str(pbf),
            f"n/place={','.join(place_types)}",
            f"n/amenity={','.join(amenities)}",
            "n/shop=supermarket",
            "n/tourism=hotel,guest_house,information",
            "-o", str(filtered_pbf),
            "--overwrite",
        ]
        run(filter_args)

        # Step 2 — export filtered PBF to GeoJSONSeq for streaming read.
        geojson = tmp / "filtered.geojsonseq"
        run([
            osmium, "export", str(filtered_pbf),
            "-o", str(geojson),
            "-f", "geojsonseq",
            "--geometry-types=point",
            "--overwrite",
        ])

        # Step 3 — stream into SQLite.
        if output.exists():
            output.unlink()
        conn = sqlite3.connect(str(output))
        try:
            ensure_schema(conn)
            cur = conn.cursor()

            place_set = set(place_types)
            amen_set = set(amenities)

            nplaces = 0
            npois = 0

            with open(geojson, encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("\x1e"):
                        # GeoJSONSeq record separator.
                        line = line.lstrip("\x1e")
                        if not line:
                            continue
                    try:
                        feat = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    geom = feat.get("geometry") or {}
                    if geom.get("type") != "Point":
                        continue
                    coords = geom.get("coordinates") or []
                    if len(coords) != 2:
                        continue
                    lon, lat = coords

                    props = feat.get("properties") or {}
                    name = pick_name(props)
                    if not name:
                        continue

                    osm_id = str(feat.get("id", ""))
                    admin = props.get("addr:province") or props.get("is_in:province") \
                        or props.get("addr:city") or props.get("is_in")

                    place_kind = props.get("place")
                    if place_kind in place_set:
                        insert_place(cur, {
                            "osm_id": osm_id,
                            "kind": place_kind,
                            "name": name,
                            "admin": admin,
                            "lat": lat,
                            "lon": lon,
                        })
                        nplaces += 1
                        continue

                    category = None
                    if props.get("amenity") in amen_set:
                        category = props.get("amenity")
                    elif props.get("shop") == "supermarket":
                        category = "supermarket"
                    elif props.get("tourism") in ("hotel", "guest_house"):
                        category = props.get("tourism")

                    if category:
                        insert_poi(cur, {
                            "osm_id": osm_id,
                            "category": category,
                            "name": name,
                            "admin": admin,
                            "lat": lat,
                            "lon": lon,
                        })
                        npois += 1

            conn.commit()
            print(f"Inserted {nplaces} places, {npois} POIs", flush=True)

            # Compact the database.
            conn.execute("VACUUM")
            conn.execute("INSERT INTO places_fts(places_fts) VALUES('optimize')")
            conn.execute("INSERT INTO pois_fts(pois_fts) VALUES('optimize')")
            conn.commit()
        finally:
            conn.close()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--pbf", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    p.add_argument("--config", required=True, type=Path)
    p.add_argument("--osmium", default="osmium")
    args = p.parse_args()

    if not args.pbf.exists():
        print(f"PBF not found: {args.pbf}", file=sys.stderr)
        return 2

    with open(args.config, encoding="utf-8") as f:
        config = yaml.safe_load(f)

    extract(args.pbf, args.output, config, args.osmium)
    print(f"Wrote {args.output} ({args.output.stat().st_size // 1024} KB)", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
