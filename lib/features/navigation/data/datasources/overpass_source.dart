import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';

class PoiCategory {
  final String id;
  final String label;
  final String icon;
  final String osmTag;
  final String color;

  const PoiCategory({
    required this.id,
    required this.label,
    required this.icon,
    required this.osmTag,
    required this.color,
  });
}

const poiCategories = [
  PoiCategory(id: 'fuel', label: 'Benzin', icon: 'local_gas_station', osmTag: 'amenity=fuel', color: '#FF9800'),
  PoiCategory(id: 'parking', label: 'Otopark', icon: 'local_parking', osmTag: 'amenity=parking', color: '#2196F3'),
  PoiCategory(id: 'hospital', label: 'Hastane', icon: 'local_hospital', osmTag: 'amenity=hospital', color: '#F44336'),
  PoiCategory(id: 'pharmacy', label: 'Eczane', icon: 'pharmacy', osmTag: 'amenity=pharmacy', color: '#4CAF50'),
  PoiCategory(id: 'restaurant', label: 'Restoran', icon: 'restaurant', osmTag: 'amenity=restaurant', color: '#E91E63'),
  PoiCategory(id: 'cafe', label: 'Kafe', icon: 'local_cafe', osmTag: 'amenity=cafe', color: '#795548'),
  PoiCategory(id: 'atm', label: 'ATM', icon: 'atm', osmTag: 'amenity=atm', color: '#009688'),
  PoiCategory(id: 'charging', label: 'Sarj', icon: 'ev_station', osmTag: 'amenity=charging_station', color: '#8BC34A'),
  PoiCategory(id: 'police', label: 'Polis', icon: 'local_police', osmTag: 'amenity=police', color: '#3F51B5'),
  PoiCategory(id: 'supermarket', label: 'Market', icon: 'shopping_cart', osmTag: 'shop=supermarket', color: '#FF5722'),
];

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

/// Fetches POIs from OSM via Overpass API with in-memory caching.
class OverpassSource {
  static const _baseUrl = 'https://overpass-api.de/api/interpreter';

  // Cache: key = "categoryId:lat_rounded:lng_rounded"
  final Map<String, List<PoiResult>> _cache = {};
  static const _cacheDuration = Duration(minutes: 10);
  final Map<String, DateTime> _cacheTime = {};

  /// Fetch POIs. Uses cache when available.
  Future<List<PoiResult>> fetchPois({
    required LatLng center,
    required List<String> categoryIds,
    int radiusMeters = 3000,
  }) async {
    if (categoryIds.isEmpty) return [];

    // Round center to ~500m grid for cache key stability.
    final gridLat = (center.latitude * 200).round() / 200;
    final gridLng = (center.longitude * 200).round() / 200;

    final results = <PoiResult>[];
    final uncachedIds = <String>[];

    // Check cache per category.
    for (final id in categoryIds) {
      final key = '$id:$gridLat:$gridLng';
      final cached = _cache[key];
      final time = _cacheTime[key];
      if (cached != null && time != null && DateTime.now().difference(time) < _cacheDuration) {
        results.addAll(cached);
      } else {
        uncachedIds.add(id);
      }
    }

    // Fetch uncached categories — try online first, fallback to offline.
    if (uncachedIds.isNotEmpty) {
      var fetched = await _fetchFromApi(
        LatLng(gridLat, gridLng),
        uncachedIds,
        radiusMeters,
      );

      // If online returned nothing, try offline POI database.
      if (fetched.isEmpty) {
        fetched = await loadOfflinePois(
          center: center,
          categoryIds: uncachedIds,
          radiusMeters: radiusMeters,
        );
      }

      // Split results by category and cache.
      for (final id in uncachedIds) {
        final catResults = fetched.where((r) => r.categoryId == id).toList();
        final key = '$id:$gridLat:$gridLng';
        _cache[key] = catResults;
        _cacheTime[key] = DateTime.now();
        results.addAll(catResults);
      }
    }

    // Limit total POIs shown.
    if (results.length > 80) {
      results.sort((a, b) {
        final da = const Distance().as(LengthUnit.Meter, center, a.position);
        final db = const Distance().as(LengthUnit.Meter, center, b.position);
        return da.compareTo(db);
      });
      return results.sublist(0, 80);
    }

    return results;
  }

  Future<List<PoiResult>> _fetchFromApi(
    LatLng center,
    List<String> categoryIds,
    int radius,
  ) async {
    final parts = <String>[];
    for (final id in categoryIds) {
      final cat = poiCategories.firstWhere((c) => c.id == id, orElse: () => poiCategories.first);
      final tagParts = cat.osmTag.split('=');
      // node + way for better coverage (some POIs are mapped as areas).
      parts.add('node["${tagParts[0]}"="${tagParts[1]}"](around:$radius,${center.latitude},${center.longitude});');
      parts.add('way["${tagParts[0]}"="${tagParts[1]}"](around:$radius,${center.latitude},${center.longitude});');
    }

    final query = '[out:json][timeout:8];(${parts.join()});out center 80;';

    try {
      final response = await http
          .post(Uri.parse(_baseUrl), body: {'data': query})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      // Parse in isolate for large responses.
      return compute(_parseOverpassResponse, _ParseArgs(response.body, categoryIds));
    } catch (e) {
      debugPrint('Overpass: $e');
      return [];
    }
  }

  /// Clear expired cache entries.
  void clearCache() {
    _cache.clear();
    _cacheTime.clear();
  }

  // ── Offline POI storage ─────────────────────────────────────────────

  static Future<Directory> _poiDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/offline_pois');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Download ALL POI categories for a bounding box and save to disk.
  /// Called during region download. Returns the number of POIs saved.
  Future<int> downloadPoisForRegion({
    required String regionName,
    required double north,
    required double south,
    required double east,
    required double west,
  }) async {
    // Build query for all categories in bounding box.
    final bbox = '$south,$west,$north,$east';
    final parts = <String>[];
    for (final cat in poiCategories) {
      final tagParts = cat.osmTag.split('=');
      parts.add('node["${tagParts[0]}"="${tagParts[1]}"]($bbox);');
      parts.add('way["${tagParts[0]}"="${tagParts[1]}"]($bbox);');
    }

    final query = '[out:json][timeout:30];(${parts.join()});out center;';

    try {
      debugPrint('POI download: $regionName');
      final response = await http
          .post(Uri.parse(_baseUrl), body: {'data': query})
          .timeout(const Duration(seconds: 35));

      if (response.statusCode != 200) return 0;

      // Parse.
      final allCategoryIds = poiCategories.map((c) => c.id).toList();
      final pois = await compute(
        _parseOverpassResponse,
        _ParseArgs(response.body, allCategoryIds),
      );

      // Save to file.
      final dir = await _poiDir();
      final normalized = regionName
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]'), '_')
          .replaceAll(RegExp(r'_+'), '_');
      final file = File('${dir.path}/$normalized.json');

      final jsonList = pois.map((p) => {
        'name': p.name,
        'lat': p.position.latitude,
        'lng': p.position.longitude,
        'cat': p.categoryId,
        'addr': p.address,
        'hours': p.openingHours,
        'phone': p.phone,
      }).toList();

      await file.writeAsString(json.encode(jsonList));
      debugPrint('POI download: $regionName — ${pois.length} POIs saved');
      return pois.length;
    } catch (e) {
      debugPrint('POI download error: $e');
      return 0;
    }
  }

  /// Load offline POIs for categories near a position.
  /// Searches all downloaded region files.
  Future<List<PoiResult>> loadOfflinePois({
    required LatLng center,
    required List<String> categoryIds,
    int radiusMeters = 3000,
  }) async {
    try {
      final dir = await _poiDir();
      if (!dir.existsSync()) return [];

      final results = <PoiResult>[];
      final catSet = categoryIds.toSet();

      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;

        final content = await entity.readAsString();
        final List<dynamic> items = json.decode(content);

        for (final item in items) {
          if (!catSet.contains(item['cat'])) continue;
          final lat = (item['lat'] as num).toDouble();
          final lng = (item['lng'] as num).toDouble();
          final pos = LatLng(lat, lng);
          final dist = const Distance().as(LengthUnit.Meter, center, pos);
          if (dist > radiusMeters) continue;

          results.add(PoiResult(
            name: item['name'] as String? ?? '',
            position: pos,
            categoryId: item['cat'] as String,
            address: item['addr'] as String?,
            openingHours: item['hours'] as String?,
            phone: item['phone'] as String?,
          ));
        }
      }

      // Sort by distance, limit.
      results.sort((a, b) {
        final da = const Distance().as(LengthUnit.Meter, center, a.position);
        final db = const Distance().as(LengthUnit.Meter, center, b.position);
        return da.compareTo(db);
      });
      return results.length > 80 ? results.sublist(0, 80) : results;
    } catch (e) {
      debugPrint('loadOfflinePois error: $e');
      return [];
    }
  }

  /// Search all downloaded POI files by name — offline text search.
  Future<List<PoiResult>> searchOfflinePois(String query) async {
    if (query.trim().length < 2) return [];
    final q = query.trim().toLowerCase();

    try {
      final dir = await _poiDir();
      if (!dir.existsSync()) return [];

      final results = <PoiResult>[];
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final items = json.decode(await entity.readAsString()) as List;
        for (final item in items) {
          final name = (item['name'] as String? ?? '').toLowerCase();
          if (name.contains(q)) {
            results.add(PoiResult(
              name: item['name'] as String? ?? '',
              position: LatLng(
                (item['lat'] as num).toDouble(),
                (item['lng'] as num).toDouble(),
              ),
              categoryId: item['cat'] as String,
              address: item['addr'] as String?,
            ));
          }
        }
      }
      return results.length > 20 ? results.sublist(0, 20) : results;
    } catch (_) {
      return [];
    }
  }

  /// Delete offline POIs for a region.
  Future<void> deleteOfflinePois(String regionName) async {
    final dir = await _poiDir();
    final normalized = regionName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    final file = File('${dir.path}/$normalized.json');
    if (file.existsSync()) await file.delete();
  }
}

class _ParseArgs {
  final String body;
  final List<String> categoryIds;
  const _ParseArgs(this.body, this.categoryIds);
}

List<PoiResult> _parseOverpassResponse(_ParseArgs args) {
  final data = json.decode(args.body);
  final elements = data['elements'] as List? ?? [];

  return elements.map<PoiResult?>((e) {
    // For way elements, use center coordinates.
    final lat = (e['lat'] ?? e['center']?['lat']) as num?;
    final lon = (e['lon'] ?? e['center']?['lon']) as num?;
    if (lat == null || lon == null) return null;

    final tags = e['tags'] as Map<String, dynamic>? ?? {};
    final name = tags['name'] as String? ?? '';

    // Determine category.
    String catId = args.categoryIds.first;
    for (final id in args.categoryIds) {
      final cat = poiCategories.firstWhere((c) => c.id == id);
      final tagParts = cat.osmTag.split('=');
      if (tags[tagParts[0]] == tagParts[1]) {
        catId = id;
        break;
      }
    }

    return PoiResult(
      name: name,
      position: LatLng(lat.toDouble(), lon.toDouble()),
      categoryId: catId,
      address: tags['addr:street'] as String?,
      openingHours: tags['opening_hours'] as String?,
      phone: tags['phone'] as String?,
    );
  }).whereType<PoiResult>().toList();
}
