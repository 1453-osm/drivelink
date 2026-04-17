import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

// ---------------------------------------------------------------------------
// Location data model
// ---------------------------------------------------------------------------
class LocationData {
  final double latitude;
  final double longitude;
  final double altitude;
  final double speedMps;
  final double speedKmh;
  final double heading;
  final double accuracy;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude = 0,
    this.speedMps = 0,
    this.speedKmh = 0,
    this.heading = 0,
    this.accuracy = 0,
    required this.timestamp,
  });

  factory LocationData.fromPosition(Position pos) {
    return LocationData(
      latitude: pos.latitude,
      longitude: pos.longitude,
      altitude: pos.altitude,
      speedMps: pos.speed,
      speedKmh: pos.speed * 3.6,
      heading: pos.heading,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
    );
  }

  static final empty = LocationData(
    latitude: 0,
    longitude: 0,
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  );

  /// Compass direction string from heading degrees.
  String get compassDirection {
    if (heading < 0) return '-';
    const directions = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
    final index = ((heading + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  /// Haversine distance in meters to another point.
  double distanceTo(double lat, double lng) {
    const earthRadius = 6371000.0; // meters
    final dLat = _toRad(lat - latitude);
    final dLng = _toRad(lng - longitude);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(latitude)) *
            math.cos(_toRad(lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Bearing in degrees to another point.
  double bearingTo(double lat, double lng) {
    final dLng = _toRad(lng - longitude);
    final lat1 = _toRad(latitude);
    final lat2 = _toRad(lat);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (_toDeg(math.atan2(y, x)) + 360) % 360;
  }

  static double _toRad(double deg) => deg * math.pi / 180;
  static double _toDeg(double rad) => rad * 180 / math.pi;

  @override
  String toString() =>
      'LocationData($latitude, $longitude, ${speedKmh.toStringAsFixed(1)} km/h)';
}

// ---------------------------------------------------------------------------
// Permission status
// ---------------------------------------------------------------------------
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}

// ---------------------------------------------------------------------------
// Location service
// ---------------------------------------------------------------------------
class LocationService {
  LocationService();

  StreamSubscription<Position>? _positionSubscription;
  bool _disposed = false;
  Completer<LocationPermissionStatus>? _initCompleter;

  final _locationController = StreamController<LocationData>.broadcast();
  final _permissionController =
      StreamController<LocationPermissionStatus>.broadcast();

  LocationData? _lastLocation;

  // ---- Public API ----

  Stream<LocationData> get locationStream => _locationController.stream;
  Stream<LocationPermissionStatus> get permissionStream =>
      _permissionController.stream;
  LocationData? get lastLocation => _lastLocation;

  /// Whether init() has completed.
  bool get isInitialized => _initCompleter?.isCompleted ?? false;

  /// Wait for init() to complete. Safe to call multiple times.
  Future<void> ensureInitialized() async {
    if (_initCompleter != null) await _initCompleter!.future;
  }

  /// Initialize the service: check permissions, get an immediate fix, and
  /// start streaming.
  Future<LocationPermissionStatus> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<LocationPermissionStatus>();

    try {
      final status = await checkAndRequestPermission();
      if (status == LocationPermissionStatus.granted) {
        // Get an immediate single fix so _lastLocation is populated before
        // the stream starts emitting.
        await getCurrentPosition();
        await startListening();
      }
      _initCompleter!.complete(status);
      return status;
    } catch (e) {
      final fallback = LocationPermissionStatus.unknown;
      _initCompleter!.complete(fallback);
      return fallback;
    }
  }

  /// Check and request location permissions.
  Future<LocationPermissionStatus> checkAndRequestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _permissionController.add(LocationPermissionStatus.serviceDisabled);
      return LocationPermissionStatus.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    final status = _mapPermission(permission);
    _permissionController.add(status);
    return status;
  }

  /// Open device location settings (useful when permission is denied forever).
  Future<bool> openSettings() => Geolocator.openLocationSettings();

  /// Start listening for position updates.
  Future<void> startListening({
    int distanceFilter = 2,
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    await _positionSubscription?.cancel();

    final locationSettings = AndroidSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
      intervalDuration: const Duration(milliseconds: 500),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'DriveLink Konum',
        notificationText: 'Konum takibi aktif',
        enableWakeLock: true,
      ),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        if (_disposed) return;
        final data = LocationData.fromPosition(position);
        _lastLocation = data;
        _locationController.add(data);
      },
      onError: (e) {
        // Silently handle — stream stays alive
      },
    );
  }

  /// Stop listening for position updates.
  Future<void> stopListening() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Get a single position fix.
  Future<LocationData?> getCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      final data = LocationData.fromPosition(pos);
      _lastLocation = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Calculate speed between two location snapshots (km/h).
  static double calculateSpeed(LocationData a, LocationData b) {
    final distanceM = a.distanceTo(b.latitude, b.longitude);
    final durationSec =
        b.timestamp.difference(a.timestamp).inMilliseconds / 1000.0;
    if (durationSec <= 0) return 0;
    return (distanceM / durationSec) * 3.6; // m/s -> km/h
  }

  // ---- Private helpers ----

  LocationPermissionStatus _mapPermission(LocationPermission p) {
    switch (p) {
      case LocationPermission.always:
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.granted;
      case LocationPermission.denied:
        return LocationPermissionStatus.denied;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      case LocationPermission.unableToDetermine:
        return LocationPermissionStatus.unknown;
    }
  }

  void dispose() {
    _disposed = true;
    _positionSubscription?.cancel();
    _locationController.close();
    _permissionController.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Awaitable provider that ensures the location service is fully initialized.
final locationServiceInitProvider =
    FutureProvider<LocationService>((ref) async {
  final service = ref.watch(locationServiceProvider);
  await service.init();
  return service;
});

final locationStreamProvider = StreamProvider<LocationData>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.locationStream;
});

final locationPermissionProvider =
    StreamProvider<LocationPermissionStatus>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.permissionStream;
});

/// The last known position — uses stream data when available, falls back
/// to the service's cached lastLocation from the initial getCurrentPosition().
/// Never returns the Istanbul fallback once a real fix has been obtained.
final lastKnownPositionProvider = Provider<LatLng?>((ref) {
  final service = ref.watch(locationServiceProvider);
  final streamLoc = ref.watch(locationStreamProvider).valueOrNull;
  final loc = streamLoc ?? service.lastLocation;
  if (loc == null) return null;
  return LatLng(loc.latitude, loc.longitude);
});

final currentSpeedProvider = Provider<double>((ref) {
  final loc = ref.watch(locationStreamProvider);
  return loc.whenOrNull(data: (d) => d.speedKmh) ?? 0;
});
