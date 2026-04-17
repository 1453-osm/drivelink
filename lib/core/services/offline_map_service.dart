import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import 'package:drivelink/features/navigation/data/datasources/overpass_source.dart';

/// Wraps MapLibre's native offline API for region download/management.
class OfflineMapService {
  /// Call once at app startup.
  Future<void> initialize() async {
    try {
      await ml.setOfflineTileCountLimit(200000);
      debugPrint('OfflineMapService: tile limit set to 200000');
    } catch (e) {
      debugPrint('OfflineMapService.initialize error: $e');
    }
  }

  /// Download a map region using MapLibre's native offline system.
  /// Tiles + glyphs + sprites are all cached internally by MapLibre.
  /// Also downloads POIs via Overpass API.
  /// Returns a stream of progress (0.0 – 1.0).
  Stream<double> downloadRegion({
    required String regionName,
    required double north,
    required double south,
    required double east,
    required double west,
    required double minZoom,
    required double maxZoom,
  }) {
    final controller = StreamController<double>();

    () async {
      try {
        debugPrint('OfflineMapService: downloading $regionName z$minZoom-$maxZoom');

        // Step 1: Download map tiles via MapLibre native (90% of progress).
        // NOTE: Legacy API — Faz 2'de TurkeyPackageService'e geçilecek.
        // mapStyleUrl boş bırakıldı çünkü artık online style kullanmıyoruz;
        // bu fonksiyon pmtiles mimarisinde no-op davranacak.
        final mlRegion = await ml.downloadOfflineRegion(
          ml.OfflineRegionDefinition(
            bounds: ml.LatLngBounds(
              southwest: ml.LatLng(south, west),
              northeast: ml.LatLng(north, east),
            ),
            mapStyleUrl: '',
            minZoom: minZoom,
            maxZoom: maxZoom,
          ),
          metadata: {'name': regionName},
          onEvent: (event) {
            if (event is ml.InProgress) {
              final p = (event.progress.clamp(0, 100)) / 100.0;
              controller.add(p * 0.9);
              if (event.progress % 10 < 1) {
                debugPrint('OfflineMapService: $regionName ${event.progress.toStringAsFixed(0)}%');
              }
            } else if (event is ml.Success) {
              debugPrint('OfflineMapService: $regionName tiles complete');
            } else if (event is ml.Error) {
              debugPrint('OfflineMapService: download event error');
            }
          },
        );

        debugPrint('OfflineMapService: $regionName MapLibre region ID=${mlRegion.id}');
        controller.add(0.92);

        // Step 2: Download POIs (10% of progress).
        try {
          final overpass = OverpassSource();
          final poiCount = await overpass.downloadPoisForRegion(
            regionName: regionName,
            north: north,
            south: south,
            east: east,
            west: west,
          );
          debugPrint('OfflineMapService: $regionName $poiCount POIs saved');
        } catch (e) {
          debugPrint('OfflineMapService: POI download failed (non-fatal): $e');
        }

        controller.add(1.0);
        debugPrint('OfflineMapService: $regionName download complete');
      } catch (e) {
        debugPrint('OfflineMapService: download error: $e');
        controller.addError(e);
      } finally {
        await controller.close();
      }
    }();

    return controller.stream;
  }

  /// Get all MapLibre offline regions.
  Future<List<ml.OfflineRegion>> getRegions() async {
    try {
      return await ml.getListOfRegions();
    } catch (e) {
      debugPrint('OfflineMapService.getRegions error: $e');
      return [];
    }
  }

  /// Delete a MapLibre offline region by ID.
  Future<void> deleteRegion(int id) async {
    try {
      await ml.deleteOfflineRegion(id);
    } catch (e) {
      debugPrint('OfflineMapService.deleteRegion error: $e');
    }
  }

  /// Delete a region by name (searches metadata).
  Future<void> deleteRegionByName(String name) async {
    try {
      final regions = await getRegions();
      for (final r in regions) {
        if (r.metadata['name'] == name) {
          await ml.deleteOfflineRegion(r.id);
        }
      }
      // Also delete POIs.
      await OverpassSource().deleteOfflinePois(name);
    } catch (e) {
      debugPrint('OfflineMapService.deleteRegionByName error: $e');
    }
  }

  /// Delete all offline regions.
  Future<void> deleteAll() async {
    try {
      final regions = await getRegions();
      for (final r in regions) {
        await ml.deleteOfflineRegion(r.id);
      }
    } catch (e) {
      debugPrint('OfflineMapService.deleteAll error: $e');
    }
  }
}

/// Global provider for the offline map service.
final offlineMapServiceProvider = Provider<OfflineMapService>((ref) {
  return OfflineMapService();
});
