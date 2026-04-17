import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:drivelink/core/services/location_service.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';

/// Rough bounding box of Türkiye (lat/lng) — used for quick "is this point
/// inside our offline coverage area?" checks. Precise polygon testing happens
/// only when we need it (rendering, route validation) using the bundled
/// GeoJSON in `assets/geo/turkey.geojson`.
const _turkeyNorth = 42.15;
const _turkeySouth = 35.80;
const _turkeyEast = 44.85;
const _turkeyWest = 25.65;

/// Center of Türkiye (near Kırıkkale), used as the default map position
/// when no GPS fix is available.
const defaultMapCenter = LatLng(39.25, 34.0);

bool _isInTurkey(LatLng point) {
  return point.latitude >= _turkeySouth &&
      point.latitude <= _turkeyNorth &&
      point.longitude >= _turkeyWest &&
      point.longitude <= _turkeyEast;
}

/// True iff the user's real GPS position is inside Türkiye and the
/// Turkey offline pack is installed. While GPS is still fixing we
/// conservatively return true to avoid showing a spurious warning.
final isCurrentLocationCoveredProvider = Provider<bool>((ref) {
  final installed =
      ref.watch(turkeyPackInstalledProvider).valueOrNull ?? false;
  if (!installed) return false;

  final loc = ref.watch(locationStreamProvider).valueOrNull;
  if (loc == null) return true;

  return _isInTurkey(LatLng(loc.latitude, loc.longitude));
});

/// Default map center: Türkiye centroid. Kept as a provider for future
/// overrides (e.g. last-known GPS, saved waypoint, etc.).
final defaultMapPositionProvider = Provider<LatLng>((_) => defaultMapCenter);
