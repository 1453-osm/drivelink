import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Key-value store for app preferences.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Records of completed (or in-progress) trips.
class TripLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startTime => dateTime()();
  DateTimeColumn get endTime => dateTime().nullable()();
  RealColumn get distanceKm => real().withDefault(const Constant(0))();
  RealColumn get avgSpeedKmh => real().withDefault(const Constant(0))();
  RealColumn get maxSpeedKmh => real().withDefault(const Constant(0))();
  RealColumn get fuelConsumedL => real().withDefault(const Constant(0))();
  RealColumn get avgConsumptionLper100 => real().withDefault(const Constant(0))();
}

/// Recently used navigation destinations for quick re-selection.
class RecentDestinations extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get lastUsed => dateTime()();
}

/// Scanned media tracks — persists even when files are temporarily unavailable.
class MediaTracks extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get filePath => text().unique()();
  TextColumn get title => text()();
  TextColumn get artist => text().withDefault(const Constant(''))();
  TextColumn get album => text().withDefault(const Constant(''))();
  TextColumn get artUri => text().nullable()();
  IntColumn get durationMs => integer().withDefault(const Constant(0))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  DateTimeColumn get dateAdded => dateTime()();
  DateTimeColumn get lastPlayed => dateTime().nullable()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get albumId => integer().nullable()();
}

/// Album grouping for tracks — may be created manually or via M3U import.
class MediaAlbums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get coverArt => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// User-created playlists.
class MediaPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Junction table linking tracks to playlists with ordering.
class MediaPlaylistEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId => integer().references(MediaPlaylists, #id)();
  IntColumn get trackId => integer().references(MediaTracks, #id)();
  IntColumn get sortOrder => integer()();
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  AppSettings,
  TripLogs,
  RecentDestinations,
  MediaTracks,
  MediaAlbums,
  MediaPlaylists,
  MediaPlaylistEntries,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Bump this when the schema changes.
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(mediaTracks);
            await m.createTable(mediaPlaylists);
            await m.createTable(mediaPlaylistEntries);
          }
          if (from < 3) {
            await m.createTable(mediaAlbums);
            await m.addColumn(mediaTracks, mediaTracks.albumId);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'drivelink.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
