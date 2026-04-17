import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:drivelink/core/database/downloaded_regions_repository.dart';
import 'package:drivelink/core/services/location_service.dart';

bool isPointCovered(LatLng point, List<DownloadedRegion> regions) {
  for (final r in regions) {
    if (point.latitude >= r.south &&
        point.latitude <= r.north &&
        point.longitude >= r.west &&
        point.longitude <= r.east) {
      return true;
    }
  }
  return false;
}

final downloadedRegionsListProvider =
    FutureProvider<List<DownloadedRegion>>((ref) async {
  final repo = ref.read(downloadedRegionsRepositoryProvider);
  return repo.getAll();
});

/// True if the user's REAL GPS position is within a downloaded region.
/// Returns true (no warning) when GPS is not yet available.
final isCurrentLocationCoveredProvider = Provider<bool>((ref) {
  final locAsync = ref.watch(locationStreamProvider);
  // Only check with real GPS data — not the fallback position.
  final loc = locAsync.valueOrNull;
  if (loc == null) return true; // No GPS yet, don't show warning.

  final point = LatLng(loc.latitude, loc.longitude);
  final regions = ref.watch(downloadedRegionsListProvider).valueOrNull ?? [];
  if (regions.isEmpty) return true;
  return isPointCovered(point, regions);
});

/// The center of the first downloaded region — used as default map position
/// instead of hardcoded Istanbul.
final defaultMapPositionProvider = Provider<LatLng>((ref) {
  final regions = ref.watch(downloadedRegionsListProvider).valueOrNull ?? [];
  if (regions.isNotEmpty) {
    final r = regions.first;
    return LatLng((r.north + r.south) / 2, (r.east + r.west) / 2);
  }
  return const LatLng(41.0082, 28.9784); // Istanbul fallback
});
