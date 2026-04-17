import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:sqlite3/sqlite3.dart';

/// A place (city/town/village/neighbourhood) from the offline addresses DB.
@immutable
class PlaceRow {
  const PlaceRow({
    required this.id,
    required this.osmId,
    required this.kind,
    required this.name,
    required this.admin,
    required this.lat,
    required this.lon,
  });

  final int id;
  final String osmId;
  final String kind;
  final String name;
  final String? admin;
  final double lat;
  final double lon;

  LatLng get position => LatLng(lat, lon);

  String get displayName =>
      (admin == null || admin!.isEmpty) ? name : '$name, $admin';
}

/// A point of interest from the offline addresses DB.
@immutable
class PoiRow {
  const PoiRow({
    required this.id,
    required this.osmId,
    required this.category,
    required this.name,
    required this.admin,
    required this.lat,
    required this.lon,
  });

  final int id;
  final String osmId;
  final String category;
  final String name;
  final String? admin;
  final double lat;
  final double lon;

  LatLng get position => LatLng(lat, lon);
}

/// Thin wrapper around the `turkey_addresses.db` SQLite + FTS5 database
/// produced by `tools/build_turkey_pack/extract_addresses.py`.
///
/// Not thread-safe — callers should serialise access or create their own
/// instance per isolate. Lifetime managed by [TurkeyPackageService]: the
/// DB is opened on first call, closed on pack uninstall.
class AddressesDb {
  AddressesDb._(this._db, this.path);

  final Database _db;
  final String path;

  static AddressesDb? _instance;

  /// Open (or return the already-open) DB at [path]. Returns null if the
  /// file doesn't exist — callers must check.
  static Future<AddressesDb?> open(String path) async {
    final existing = _instance;
    if (existing != null && existing.path == path && existing._isOpen) {
      return existing;
    }
    try {
      final db = sqlite3.open(path, mode: OpenMode.readOnly);
      final inst = AddressesDb._(db, path);
      _instance?.close();
      _instance = inst;
      return inst;
    } catch (e) {
      debugPrint('AddressesDb.open failed ($path): $e');
      return null;
    }
  }

  bool _isOpen = true;

  void close() {
    if (!_isOpen) return;
    try {
      _db.dispose();
    } catch (_) {}
    _isOpen = false;
    if (identical(_instance, this)) _instance = null;
  }

  /// Full-text search of places. Results are ordered by bm25 relevance;
  /// optionally re-ranked by distance to [near].
  List<PlaceRow> searchPlaces(
    String query, {
    int limit = 20,
    LatLng? near,
  }) {
    final match = _toMatchQuery(query);
    if (match == null) return const [];

    final rows = _db.select(
      '''
      SELECT p.id, p.osm_id, p.kind, p.name, p.admin, p.lat, p.lon
      FROM places_fts
      JOIN places p ON p.id = places_fts.rowid
      WHERE places_fts MATCH ?
      ORDER BY bm25(places_fts)
      LIMIT ?
      ''',
      [match, limit * 3],
    );

    final list = rows.map(_placeFromRow).toList();
    if (near != null) {
      list.sort((a, b) {
        final da = _distanceM(near, a.position);
        final db = _distanceM(near, b.position);
        return da.compareTo(db);
      });
    }
    return list.take(limit).toList();
  }

  /// Full-text search of POIs, optionally constrained to [categories]
  /// (matching `PoiCategory.id`, which equals the DB `category` column).
  List<PoiRow> searchPois(
    String query, {
    int limit = 40,
    Set<String>? categories,
    LatLng? near,
  }) {
    final match = _toMatchQuery(query);
    if (match == null) return const [];

    final whereCat = categories == null || categories.isEmpty
        ? ''
        : 'AND p.category IN (${List.filled(categories.length, '?').join(',')})';

    final rows = _db.select(
      '''
      SELECT p.id, p.osm_id, p.category, p.name, p.admin, p.lat, p.lon
      FROM pois_fts
      JOIN pois p ON p.id = pois_fts.rowid
      WHERE pois_fts MATCH ? $whereCat
      ORDER BY bm25(pois_fts)
      LIMIT ?
      ''',
      [match, ...?categories, limit * 3],
    );

    final list = rows.map(_poiFromRow).toList();
    if (near != null) {
      list.sort((a, b) {
        final da = _distanceM(near, a.position);
        final db = _distanceM(near, b.position);
        return da.compareTo(db);
      });
    }
    return list.take(limit).toList();
  }

  /// Return POIs within [radiusM] of [center], optionally filtered by
  /// [categories]. Uses a bounding-box lat/lon scan for index friendliness,
  /// then filters to the exact great-circle radius.
  List<PoiRow> poisNear(
    LatLng center, {
    required Set<String> categories,
    int radiusM = 3000,
    int limit = 80,
  }) {
    if (categories.isEmpty) return const [];

    final (minLat, maxLat, minLon, maxLon) = _bbox(center, radiusM);

    final rows = _db.select(
      '''
      SELECT id, osm_id, category, name, admin, lat, lon
      FROM pois
      WHERE category IN (${List.filled(categories.length, '?').join(',')})
        AND lat BETWEEN ? AND ?
        AND lon BETWEEN ? AND ?
      LIMIT ?
      ''',
      [...categories, minLat, maxLat, minLon, maxLon, limit * 4],
    );

    final list = rows
        .map(_poiFromRow)
        .where((p) => _distanceM(center, p.position) <= radiusM)
        .toList()
      ..sort((a, b) {
        final da = _distanceM(center, a.position);
        final db = _distanceM(center, b.position);
        return da.compareTo(db);
      });

    return list.take(limit).toList();
  }

  /// Return the nearest named place(s) within [radiusM] of [center].
  /// Useful for reverse geocoding ("where am I?").
  List<PlaceRow> placesNear(
    LatLng center, {
    int radiusM = 20000,
    int limit = 5,
  }) {
    final (minLat, maxLat, minLon, maxLon) = _bbox(center, radiusM);

    final rows = _db.select(
      '''
      SELECT id, osm_id, kind, name, admin, lat, lon
      FROM places
      WHERE lat BETWEEN ? AND ?
        AND lon BETWEEN ? AND ?
      LIMIT ?
      ''',
      [minLat, maxLat, minLon, maxLon, limit * 8],
    );

    final list = rows
        .map(_placeFromRow)
        .where((p) => _distanceM(center, p.position) <= radiusM)
        .toList()
      ..sort((a, b) {
        final da = _distanceM(center, a.position);
        final db = _distanceM(center, b.position);
        return da.compareTo(db);
      });
    return list.take(limit).toList();
  }

  (double, double, double, double) _bbox(LatLng center, int radiusM) {
    final dLat = radiusM / 111000.0;
    final dLon = radiusM / (111000.0 * math.cos(center.latitude * math.pi / 180.0));
    return (
      center.latitude - dLat,
      center.latitude + dLat,
      center.longitude - dLon,
      center.longitude + dLon,
    );
  }

  /// Build a safe FTS5 `MATCH` expression from user input. Splits the
  /// query into tokens, appends `*` for prefix matching, joins with AND.
  /// Returns null for an empty query (caller short-circuits).
  String? _toMatchQuery(String query) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return null;
    return tokens.map((t) => '$t*').join(' ');
  }

  PlaceRow _placeFromRow(Row r) => PlaceRow(
        id: r['id'] as int,
        osmId: r['osm_id'] as String? ?? '',
        kind: r['kind'] as String? ?? '',
        name: r['name'] as String? ?? '',
        admin: r['admin'] as String?,
        lat: (r['lat'] as num).toDouble(),
        lon: (r['lon'] as num).toDouble(),
      );

  PoiRow _poiFromRow(Row r) => PoiRow(
        id: r['id'] as int,
        osmId: r['osm_id'] as String? ?? '',
        category: r['category'] as String? ?? '',
        name: r['name'] as String? ?? '',
        admin: r['admin'] as String?,
        lat: (r['lat'] as num).toDouble(),
        lon: (r['lon'] as num).toDouble(),
      );

  static double _distanceM(LatLng a, LatLng b) =>
      const Distance().as(LengthUnit.Meter, a, b);
}
