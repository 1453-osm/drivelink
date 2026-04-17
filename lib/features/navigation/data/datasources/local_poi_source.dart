import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:drivelink/core/database/addresses_db.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';

/// Metadata describing a POI category the user can toggle on the map.
class PoiCategory {
  final String id;
  final String label;
  final String icon;
  final String color;

  const PoiCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
  });
}

/// Categories shipped in the offline addresses DB. [id] must match the
/// `category` column values emitted by `extract_addresses.py`.
const poiCategories = [
  PoiCategory(id: 'fuel', label: 'Benzin', icon: 'local_gas_station', color: '#FF9800'),
  PoiCategory(id: 'parking', label: 'Otopark', icon: 'local_parking', color: '#2196F3'),
  PoiCategory(id: 'hospital', label: 'Hastane', icon: 'local_hospital', color: '#F44336'),
  PoiCategory(id: 'pharmacy', label: 'Eczane', icon: 'pharmacy', color: '#4CAF50'),
  PoiCategory(id: 'restaurant', label: 'Restoran', icon: 'restaurant', color: '#E91E63'),
  PoiCategory(id: 'cafe', label: 'Kafe', icon: 'local_cafe', color: '#795548'),
  PoiCategory(id: 'atm', label: 'ATM', icon: 'atm', color: '#009688'),
  PoiCategory(id: 'charging_station', label: 'Sarj', icon: 'ev_station', color: '#8BC34A'),
  PoiCategory(id: 'police', label: 'Polis', icon: 'local_police', color: '#3F51B5'),
  PoiCategory(id: 'supermarket', label: 'Market', icon: 'shopping_cart', color: '#FF5722'),
];

/// Presentation-level POI result consumed by the map UI.
class PoiResult {
  final String name;
  final LatLng position;
  final String categoryId;
  final String? address;
  final String? openingHours;
  final String? phone;

  const PoiResult({
    required this.name,
    required this.position,
    required this.categoryId,
    this.address,
    this.openingHours,
    this.phone,
  });
}

/// Offline POI source backed by the installed Turkey addresses DB.
///
/// Degrades gracefully when the pack isn't installed — all methods return
/// an empty list and the UI simply shows nothing.
class LocalPoiSource {
  LocalPoiSource(this._pack);

  final TurkeyPackageService _pack;

  /// Load POIs within a radius of [center], filtered by [categoryIds].
  Future<List<PoiResult>> fetchPois({
    required LatLng center,
    required List<String> categoryIds,
    int radiusMeters = 3000,
  }) async {
    if (categoryIds.isEmpty) return const [];
    final dbPath = await _pack.installedAddressesPath();
    if (dbPath == null) return const [];

    final db = await AddressesDb.open(dbPath);
    if (db == null) return const [];

    final rows = db.poisNear(
      center,
      categories: categoryIds.toSet(),
      radiusM: radiusMeters,
      limit: 80,
    );
    return rows.map(_toPoiResult).toList();
  }

  /// Free-text search across POI names — returns [PoiResult]s directly.
  /// Used by the address search screen as a secondary source after places.
  Future<List<PoiResult>> searchPois(String query, {int limit = 20}) async {
    final dbPath = await _pack.installedAddressesPath();
    if (dbPath == null) return const [];

    final db = await AddressesDb.open(dbPath);
    if (db == null) return const [];

    final rows = db.searchPois(query, limit: limit);
    return rows.map(_toPoiResult).toList();
  }

  PoiResult _toPoiResult(PoiRow r) => PoiResult(
        name: r.name,
        position: r.position,
        categoryId: r.category,
        address: r.admin,
      );
}

final localPoiSourceProvider = Provider<LocalPoiSource>((ref) {
  return LocalPoiSource(ref.watch(turkeyPackageServiceProvider));
});
