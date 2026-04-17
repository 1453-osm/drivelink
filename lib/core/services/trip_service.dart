import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/core/database/trip_repository.dart';
import 'package:drivelink/core/services/location_service.dart';
import 'package:drivelink/features/obd/domain/models/obd_data.dart';
import 'package:drivelink/features/obd/presentation/providers/obd_providers.dart';
import 'package:drivelink/features/trip_computer/presentation/widgets/trip_history.dart';

// ---------------------------------------------------------------------------
// Trip data model
// ---------------------------------------------------------------------------

/// Snapshot of the current trip's accumulated statistics.
class TripData {
  /// Total distance travelled in km.
  final double distanceKm;

  /// Elapsed time since trip start.
  final Duration elapsed;

  /// Average speed over the trip in km/h.
  final double avgSpeedKmh;

  /// Maximum speed recorded during the trip in km/h.
  final double maxSpeedKmh;

  /// Current instantaneous fuel consumption in L/100km.
  final double currentConsumptionLper100km;

  /// Average fuel consumption over the trip in L/100km.
  final double avgConsumptionLper100km;

  /// Total fuel consumed during the trip in litres.
  final double totalFuelLitres;

  /// Whether a trip is currently active.
  final bool isActive;

  const TripData({
    this.distanceKm = 0,
    this.elapsed = Duration.zero,
    this.avgSpeedKmh = 0,
    this.maxSpeedKmh = 0,
    this.currentConsumptionLper100km = 0,
    this.avgConsumptionLper100km = 0,
    this.totalFuelLitres = 0,
    this.isActive = false,
  });

  /// Elapsed time formatted as minutes (double) for widget compatibility.
  double get elapsedMinutes => elapsed.inSeconds / 60.0;

  TripData copyWith({
    double? distanceKm,
    Duration? elapsed,
    double? avgSpeedKmh,
    double? maxSpeedKmh,
    double? currentConsumptionLper100km,
    double? avgConsumptionLper100km,
    double? totalFuelLitres,
    bool? isActive,
  }) {
    return TripData(
      distanceKm: distanceKm ?? this.distanceKm,
      elapsed: elapsed ?? this.elapsed,
      avgSpeedKmh: avgSpeedKmh ?? this.avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh ?? this.maxSpeedKmh,
      currentConsumptionLper100km:
          currentConsumptionLper100km ?? this.currentConsumptionLper100km,
      avgConsumptionLper100km:
          avgConsumptionLper100km ?? this.avgConsumptionLper100km,
      totalFuelLitres: totalFuelLitres ?? this.totalFuelLitres,
      isActive: isActive ?? this.isActive,
    );
  }
}

// ---------------------------------------------------------------------------
// Trip service — accumulates GPS distance, OBD speed/fuel data
// ---------------------------------------------------------------------------

class TripService {
  TripService(this._tripRepository);

  final TripRepository _tripRepository;

  final _controller = StreamController<TripData>.broadcast();

  Stream<TripData> get stream => _controller.stream;

  // ── Internal state ──────────────────────────────────────────────────────
  bool _active = false;
  DateTime? _startTime;
  Timer? _timer;

  double _distanceKm = 0;
  double _maxSpeedKmh = 0;

  // For average speed calculation
  double _speedSum = 0;
  int _speedSamples = 0;

  // For fuel tracking
  double _totalFuelLitres = 0;
  double _currentFuelRateLph = 0; // L/h from OBD
  double _currentSpeedKmh = 0;
  double _fuelConsumptionSum = 0; // sum of L/100km samples
  int _fuelSamples = 0;

  // Previous GPS position for distance accumulation
  LocationData? _prevLocation;

  TripData _lastData = const TripData();

  // ── Database trip row ID ────────────────────────────────────────────────
  int? _currentTripId;
  DateTime? _lastDbUpdate;
  static const _dbUpdateInterval = Duration(seconds: 30);

  // ── Completed trips (in-memory cache, synced from DB) ─────────────────
  final List<TripRecord> _tripHistory = [];
  List<TripRecord> get tripHistory => List.unmodifiable(_tripHistory);

  /// Load trip history from the database into the in-memory cache.
  Future<void> loadHistory() async {
    try {
      final dbTrips = await _tripRepository.getRecentTrips(limit: 20);
      _tripHistory
        ..clear()
        ..addAll(dbTrips.map(_tripLogToRecord));
    } catch (e) {
      debugPrint('TripService.loadHistory error: $e');
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────

  bool get isActive => _active;
  TripData get currentData => _lastData;

  Future<void> startTrip() async {
    if (_active) return;
    _active = true;
    _startTime = DateTime.now();
    _distanceKm = 0;
    _maxSpeedKmh = 0;
    _speedSum = 0;
    _speedSamples = 0;
    _totalFuelLitres = 0;
    _currentFuelRateLph = 0;
    _currentSpeedKmh = 0;
    _fuelConsumptionSum = 0;
    _fuelSamples = 0;
    _prevLocation = null;
    _lastDbUpdate = null;

    // Create a DB row for this trip.
    try {
      _currentTripId = await _tripRepository.startTrip();
    } catch (e) {
      debugPrint('TripService: failed to create DB trip row: $e');
    }

    // Tick every second to update elapsed time and fuel accumulation.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _emit();
  }

  Future<void> stopTrip() async {
    if (!_active) return;
    _active = false;
    _timer?.cancel();
    _timer = null;

    // Persist final stats to DB and add to in-memory cache.
    if (_distanceKm > 0.01) {
      final record = TripRecord(
        date: _startTime ?? DateTime.now(),
        distanceKm: _distanceKm,
        durationMinutes: _lastData.elapsedMinutes,
        avgSpeedKmh: _lastData.avgSpeedKmh,
        avgConsumption: _lastData.avgConsumptionLper100km,
      );
      _tripHistory.insert(0, record);

      if (_currentTripId != null) {
        try {
          await _tripRepository.updateTrip(
            _currentTripId!,
            distance: _distanceKm,
            avgSpeed: _lastData.avgSpeedKmh,
            maxSpeed: _maxSpeedKmh,
            fuel: _totalFuelLitres,
            avgConsumption: _lastData.avgConsumptionLper100km,
          );
          await _tripRepository.endTrip(_currentTripId!);
        } catch (e) {
          debugPrint('TripService: failed to persist trip to DB: $e');
        }
      }
    }

    _currentTripId = null;
    _emit();
  }

  void resetTrip() {
    stopTrip();
    _distanceKm = 0;
    _maxSpeedKmh = 0;
    _speedSum = 0;
    _speedSamples = 0;
    _totalFuelLitres = 0;
    _fuelConsumptionSum = 0;
    _fuelSamples = 0;
    _prevLocation = null;
    _startTime = null;
    _lastData = const TripData();
    _emit();
  }

  // ── Data ingestion (called by providers) ────────────────────────────────

  void onLocationUpdate(LocationData loc) {
    if (!_active) return;

    // Accumulate distance via haversine
    if (_prevLocation != null) {
      final distM = _prevLocation!.distanceTo(loc.latitude, loc.longitude);
      // Filter out GPS jumps (> 500m between 0.5s samples is unrealistic)
      if (distM < 500) {
        _distanceKm += distM / 1000.0;
      }
    }
    _prevLocation = loc;
  }

  void onObdUpdate(ObdData obd) {
    if (!_active) return;

    // Speed tracking
    final speed = obd.speed ?? 0;
    _currentSpeedKmh = speed;
    if (speed > 0) {
      _speedSum += speed;
      _speedSamples++;
      if (speed > _maxSpeedKmh) {
        _maxSpeedKmh = speed;
      }
    }

    // Fuel rate tracking (OBD fuelRate is in L/h)
    final fuelRate = obd.fuelRate ?? 0;
    _currentFuelRateLph = fuelRate;

    // Calculate instantaneous L/100km
    if (speed > 2) {
      final lPer100 = (fuelRate / speed) * 100;
      _fuelConsumptionSum += lPer100;
      _fuelSamples++;
    }
  }

  // ── Private ─────────────────────────────────────────────────────────────

  void _tick() {
    if (!_active || _startTime == null) return;

    // Accumulate fuel consumed: L/h / 3600 = litres per second
    _totalFuelLitres += _currentFuelRateLph / 3600.0;

    // Periodically persist intermediate stats to the database.
    _persistIfDue();

    _emit();
  }

  void _persistIfDue() {
    if (_currentTripId == null) return;
    final now = DateTime.now();
    if (_lastDbUpdate != null &&
        now.difference(_lastDbUpdate!) < _dbUpdateInterval) {
      return;
    }
    _lastDbUpdate = now;
    _tripRepository
        .updateTrip(
          _currentTripId!,
          distance: _distanceKm,
          avgSpeed: _lastData.avgSpeedKmh,
          maxSpeed: _maxSpeedKmh,
          fuel: _totalFuelLitres,
          avgConsumption: _lastData.avgConsumptionLper100km,
        )
        .catchError(
            (e) => debugPrint('TripService: periodic DB update failed: $e'));
  }

  void _emit() {
    final elapsed = _active && _startTime != null
        ? DateTime.now().difference(_startTime!)
        : Duration.zero;

    final avgSpeed =
        _speedSamples > 0 ? _speedSum / _speedSamples : 0.0;

    // Current instantaneous consumption
    double currentConsumption = 0;
    if (_currentSpeedKmh > 2 && _currentFuelRateLph > 0) {
      currentConsumption = (_currentFuelRateLph / _currentSpeedKmh) * 100;
    }

    // Average consumption
    final avgConsumption =
        _fuelSamples > 0 ? _fuelConsumptionSum / _fuelSamples : 0.0;

    _lastData = TripData(
      distanceKm: _distanceKm,
      elapsed: elapsed,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: _maxSpeedKmh,
      currentConsumptionLper100km: currentConsumption,
      avgConsumptionLper100km: avgConsumption,
      totalFuelLitres: _totalFuelLitres,
      isActive: _active,
    );

    if (!_controller.isClosed) {
      _controller.add(_lastData);
    }
  }

  /// Convert a Drift [TripLog] row to the UI [TripRecord] model.
  static TripRecord _tripLogToRecord(TripLog log) {
    final duration = log.endTime != null
        ? log.endTime!.difference(log.startTime)
        : Duration.zero;
    return TripRecord(
      date: log.startTime,
      distanceKm: log.distanceKm,
      durationMinutes: duration.inSeconds / 60.0,
      avgSpeedKmh: log.avgSpeedKmh,
      avgConsumption: log.avgConsumptionLper100,
    );
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

// ---------------------------------------------------------------------------
// Riverpod Providers
// ---------------------------------------------------------------------------

/// Singleton trip service backed by the Drift database.
final tripServiceProvider = Provider<TripService>((ref) {
  final repo = ref.watch(tripRepositoryProvider);
  final service = TripService(repo);

  // Load persisted trip history on startup.
  service.loadHistory();

  // Listen to GPS location updates
  ref.listen<AsyncValue<LocationData>>(locationStreamProvider, (prev, next) {
    final loc = next.valueOrNull;
    if (loc != null) {
      service.onLocationUpdate(loc);
    }
  });

  // Listen to OBD data updates
  ref.listen<AsyncValue<ObdData>>(obdDataProvider, (prev, next) {
    final obd = next.valueOrNull;
    if (obd != null) {
      service.onObdUpdate(obd);
    }
  });

  ref.onDispose(() => service.dispose());
  return service;
});

/// Live trip data stream.
final tripDataProvider = StreamProvider<TripData>((ref) {
  final service = ref.watch(tripServiceProvider);
  return service.stream;
});

/// Current trip data (synchronous snapshot).
final currentTripDataProvider = Provider<TripData>((ref) {
  final async = ref.watch(tripDataProvider);
  return async.valueOrNull ?? const TripData();
});

/// Whether a trip is currently active.
final tripActiveProvider = Provider<bool>((ref) {
  return ref.watch(currentTripDataProvider).isActive;
});

/// Trip history — reads from the Drift database, falls back to in-memory cache.
final tripHistoryProvider = FutureProvider<List<TripRecord>>((ref) async {
  // Re-read when trip data changes (a stop creates a new history entry)
  ref.watch(tripDataProvider);
  final repo = ref.watch(tripRepositoryProvider);
  try {
    final dbTrips = await repo.getRecentTrips(limit: 20);
    return dbTrips.map(TripService._tripLogToRecord).toList();
  } catch (e) {
    // Fallback to in-memory cache if DB read fails.
    debugPrint('tripHistoryProvider: DB read failed, using cache: $e');
    final service = ref.read(tripServiceProvider);
    return service.tripHistory;
  }
});
