import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'database_provider.dart';
import 'settings_repository.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

/// A region that has been downloaded for offline map use.
class DownloadedRegion {
  final String name;
  final String subtitle;
  final double north, south, east, west;
  final int minZoom, maxZoom;
  final DateTime downloadedAt;
  final double sizeKiB; // recorded at download time

  const DownloadedRegion({
    required this.name,
    required this.subtitle,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
    required this.minZoom,
    required this.maxZoom,
    required this.downloadedAt,
    required this.sizeKiB,
  });

  /// Normalized store name for FMTC.
  String get storeName => 'region_${_normalize(name)}';

  static String _normalize(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'subtitle': subtitle,
        'north': north,
        'south': south,
        'east': east,
        'west': west,
        'minZoom': minZoom,
        'maxZoom': maxZoom,
        'downloadedAt': downloadedAt.toIso8601String(),
        'sizeKiB': sizeKiB,
      };

  factory DownloadedRegion.fromJson(Map<String, dynamic> json) {
    return DownloadedRegion(
      name: json['name'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      north: (json['north'] as num).toDouble(),
      south: (json['south'] as num).toDouble(),
      east: (json['east'] as num).toDouble(),
      west: (json['west'] as num).toDouble(),
      minZoom: json['minZoom'] as int,
      maxZoom: json['maxZoom'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      sizeKiB: (json['sizeKiB'] as num).toDouble(),
    );
  }

  /// Human-readable size string.
  String get formattedSize {
    if (sizeKiB < 1024) return '${sizeKiB.toStringAsFixed(0)} KB';
    final mb = sizeKiB / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    return '${(mb / 1024).toStringAsFixed(2)} GB';
  }
}

// ---------------------------------------------------------------------------
// Repository — persists downloaded region metadata via AppSettings JSON
// ---------------------------------------------------------------------------

const _settingsKey = 'downloaded_regions';

class DownloadedRegionsRepository {
  DownloadedRegionsRepository(this._db);

  final AppDatabase _db;

  // ── In-memory cache to avoid repeated DB reads ──
  List<DownloadedRegion>? _cache;

  /// Force next getAll() to re-read from database.
  void clearCache() => _cache = null;

  Future<List<DownloadedRegion>> getAll() async {
    if (_cache != null) return List.unmodifiable(_cache!);

    final repo = SettingsRepository(_db);
    final raw = await repo.get(_settingsKey);
    if (raw == null || raw.isEmpty) {
      _cache = [];
      return [];
    }
    try {
      final List<dynamic> list = json.decode(raw);
      _cache = list
          .map((e) => DownloadedRegion.fromJson(e as Map<String, dynamic>))
          .toList();
      return List.unmodifiable(_cache!);
    } catch (_) {
      _cache = [];
      return [];
    }
  }

  Future<void> add(DownloadedRegion region) async {
    final regions = List<DownloadedRegion>.from(await getAll());
    // Replace if same name exists (re-download).
    regions.removeWhere(
        (r) => r.storeName == region.storeName);
    regions.add(region);
    await _save(regions);
  }

  Future<void> remove(String storeName) async {
    final regions = List<DownloadedRegion>.from(await getAll());
    regions.removeWhere((r) => r.storeName == storeName);
    await _save(regions);
  }

  Future<void> removeAll() async {
    await _save([]);
  }

  /// Check if a region with the given name is already downloaded.
  Future<bool> isDownloaded(String regionName) async {
    final regions = await getAll();
    final normalized = DownloadedRegion._normalize(regionName);
    return regions.any((r) => r.storeName == 'region_$normalized');
  }

  Future<void> _save(List<DownloadedRegion> regions) async {
    _cache = regions;
    final repo = SettingsRepository(_db);
    final raw = json.encode(regions.map((r) => r.toJson()).toList());
    await repo.set(_settingsKey, raw);
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final downloadedRegionsRepositoryProvider =
    Provider<DownloadedRegionsRepository>((ref) {
  return DownloadedRegionsRepository(ref.watch(databaseProvider));
});

/// True when at least one region has been downloaded.
final hasDownloadedRegionsProvider = FutureProvider<bool>((ref) async {
  final repo = ref.read(downloadedRegionsRepositoryProvider);
  final list = await repo.getAll();
  return list.isNotEmpty;
});
