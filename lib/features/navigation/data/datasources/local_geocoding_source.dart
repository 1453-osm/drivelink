import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:drivelink/core/database/addresses_db.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';
import 'package:drivelink/features/navigation/data/datasources/local_poi_source.dart';

/// Lightweight record returned by geocoding queries — mirrors the shape
/// consumed by the search screen and recent-destinations cache.
typedef GeocodingResult = ({String displayName, LatLng coordinate});

/// Offline geocoder backed by the installed Turkey addresses DB.
///
/// Search strategy:
///   1. FTS5 query against `places` (cities/towns/villages/neighbourhoods)
///   2. FTS5 query against `pois` (fuel stations, cafés, hospitals, …)
///   3. Merge, dedupe by coordinate, return up to [limit] results
class LocalGeocodingSource {
  LocalGeocodingSource(this._pack, this._poi);

  final TurkeyPackageService _pack;
  final LocalPoiSource _poi;

  /// Unified address/place search.
  Future<List<GeocodingResult>> search(
    String query, {
    int limit = 20,
    LatLng? near,
  }) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    final dbPath = await _pack.installedAddressesPath();
    if (dbPath == null) return const [];

    final db = await AddressesDb.open(dbPath);
    if (db == null) return const [];

    final places = db.searchPlaces(q, limit: limit, near: near);
    final pois = db.searchPois(q, limit: limit, near: near);

    final results = <GeocodingResult>[];
    final seen = <String>{};

    for (final p in places) {
      final key = '${p.lat.toStringAsFixed(5)}_${p.lon.toStringAsFixed(5)}';
      if (seen.add(key)) {
        results.add((displayName: p.displayName, coordinate: p.position));
      }
    }
    for (final p in pois) {
      final key = '${p.lat.toStringAsFixed(5)}_${p.lon.toStringAsFixed(5)}';
      if (seen.add(key)) {
        final label = p.admin == null || p.admin!.isEmpty
            ? p.name
            : '${p.name} — ${p.admin}';
        results.add((displayName: label, coordinate: p.position));
      }
    }

    return results.take(limit).toList();
  }

  /// Returns the nearest named place (city/town/village) within [radiusM]
  /// of [point]. Useful for "where am I?" labels.
  Future<GeocodingResult?> reverseGeocode(
    LatLng point, {
    int radiusM = 20000,
  }) async {
    // We don't have a dedicated reverse index — instead fetch the closest
    // named place via the POI-radius helper on the `places` table style.
    final dbPath = await _pack.installedAddressesPath();
    if (dbPath == null) return null;
    final db = await AddressesDb.open(dbPath);
    if (db == null) return null;

    final places = db.placesNear(point, radiusM: radiusM, limit: 1);
    if (places.isEmpty) return null;
    final p = places.first;
    return (displayName: p.displayName, coordinate: p.position);
  }
}

final localGeocodingSourceProvider = Provider<LocalGeocodingSource>((ref) {
  return LocalGeocodingSource(
    ref.watch(turkeyPackageServiceProvider),
    ref.watch(localPoiSourceProvider),
  );
});
