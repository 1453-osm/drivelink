import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class TripRepository {
  TripRepository(this._db);

  final AppDatabase _db;

  /// Create a new trip log with the current time as start. Returns the row id.
  Future<int> startTrip() async {
    return _db.into(_db.tripLogs).insert(
          TripLogsCompanion.insert(startTime: DateTime.now()),
        );
  }

  /// Update trip statistics while the trip is in progress.
  Future<void> updateTrip(
    int id, {
    double? distance,
    double? avgSpeed,
    double? maxSpeed,
    double? fuel,
    double? avgConsumption,
  }) async {
    final companion = TripLogsCompanion(
      distanceKm: distance != null ? Value(distance) : const Value.absent(),
      avgSpeedKmh: avgSpeed != null ? Value(avgSpeed) : const Value.absent(),
      maxSpeedKmh: maxSpeed != null ? Value(maxSpeed) : const Value.absent(),
      fuelConsumedL: fuel != null ? Value(fuel) : const Value.absent(),
      avgConsumptionLper100:
          avgConsumption != null ? Value(avgConsumption) : const Value.absent(),
    );

    await (_db.update(_db.tripLogs)..where((t) => t.id.equals(id)))
        .write(companion);
  }

  /// Mark a trip as finished by setting its end time.
  Future<void> endTrip(int id) async {
    await (_db.update(_db.tripLogs)..where((t) => t.id.equals(id))).write(
      TripLogsCompanion(endTime: Value(DateTime.now())),
    );
  }

  /// Fetch the most recent trips, newest first.
  Future<List<TripLog>> getRecentTrips({int limit = 20}) async {
    final query = _db.select(_db.tripLogs)
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
      ..limit(limit);
    return query.get();
  }

  /// Watch the currently active trip (one with no end time).
  ///
  /// Emits `null` when there is no active trip.
  Stream<TripLog?> watchActiveTrip() {
    final query = _db.select(_db.tripLogs)
      ..where((t) => t.endTime.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.startTime)])
      ..limit(1);
    return query.watchSingleOrNull();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepository(ref.watch(databaseProvider));
});
