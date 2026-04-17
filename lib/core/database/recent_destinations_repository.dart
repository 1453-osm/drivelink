import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database.dart';
import 'database_provider.dart';

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class RecentDestinationsRepository {
  RecentDestinationsRepository(this._db);

  final AppDatabase _db;

  /// Add or update a recent destination.
  ///
  /// If a destination with the same name already exists its [lastUsed]
  /// timestamp is refreshed; otherwise a new row is inserted.
  Future<void> addDestination(String name, double lat, double lng) async {
    // Remove previous entry with same name to avoid duplicates.
    await (_db.delete(_db.recentDestinations)
          ..where((d) => d.name.equals(name)))
        .go();

    await _db.into(_db.recentDestinations).insert(
          RecentDestinationsCompanion.insert(
            name: name,
            latitude: lat,
            longitude: lng,
            lastUsed: DateTime.now(),
          ),
        );

    // Keep at most 20 entries — trim the oldest.
    final all = await (_db.select(_db.recentDestinations)
          ..orderBy([(d) => OrderingTerm.desc(d.lastUsed)]))
        .get();

    if (all.length > 20) {
      final idsToKeep = all.take(20).map((d) => d.id).toSet();
      await (_db.delete(_db.recentDestinations)
            ..where((d) => d.id.isNotIn(idsToKeep)))
          .go();
    }
  }

  /// Fetch the most recently used destinations, newest first.
  Future<List<RecentDestination>> getRecent({int limit = 10}) async {
    final query = _db.select(_db.recentDestinations)
      ..orderBy([(d) => OrderingTerm.desc(d.lastUsed)])
      ..limit(limit);
    return query.get();
  }

  /// Delete all recent destinations.
  Future<void> clearAll() async {
    await _db.delete(_db.recentDestinations).go();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final recentDestinationsRepositoryProvider =
    Provider<RecentDestinationsRepository>((ref) {
  return RecentDestinationsRepository(ref.watch(databaseProvider));
});
