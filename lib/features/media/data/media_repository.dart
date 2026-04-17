import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/core/database/database.dart';
import 'package:drivelink/core/database/database_provider.dart';

/// Data class for batch-upserting scanned tracks.
class ScannedTrack {
  const ScannedTrack({
    required this.filePath,
    required this.title,
    this.artist = '',
    this.album = '',
    this.artUri,
    this.albumId,
  });

  final String filePath;
  final String title;
  final String artist;
  final String album;
  final String? artUri;
  final int? albumId;
}

/// Repository for all media-related database operations.
class MediaRepository {
  MediaRepository(this._db);

  final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Tracks
  // ---------------------------------------------------------------------------

  /// Watch all tracks ordered by title.
  Stream<List<MediaTrack>> watchAllTracks() {
    final query = _db.select(_db.mediaTracks)
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return query.watch();
  }

  /// Get all tracks (one-shot).
  Future<List<MediaTrack>> getAllTracks() {
    final query = _db.select(_db.mediaTracks)
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return query.get();
  }

  /// Upsert a single track — insert if new, update title/artist/artUri if exists.
  Future<void> upsertTrack(ScannedTrack track) async {
    final albumCover = await _albumCoverForId(track.albumId);
    await _db.into(_db.mediaTracks).insertOnConflictUpdate(
          MediaTracksCompanion(
            filePath: Value(track.filePath),
            title: Value(track.title),
            artist: Value(track.artist),
            album: Value(track.album),
            artUri: Value(albumCover ?? track.artUri),
            albumId: Value(track.albumId),
            dateAdded: Value(DateTime.now()),
          ),
        );
  }

  /// Batch upsert scanned tracks. If [albumId] is provided, it is applied to
  /// every track regardless of what's in each [ScannedTrack].
  Future<void> upsertTracks(
    List<ScannedTrack> tracks, {
    int? albumId,
  }) async {
    final albumCover = await _albumCoverForId(albumId);
    await _db.batch((batch) {
      for (final track in tracks) {
        final resolvedAlbumId = albumId ?? track.albumId;
        final effectiveArtUri = albumCover ?? track.artUri;
        batch.insert(
          _db.mediaTracks,
          MediaTracksCompanion(
            filePath: Value(track.filePath),
            title: Value(track.title),
            artist: Value(track.artist),
            album: Value(track.album),
            artUri: Value(effectiveArtUri),
            albumId: Value(resolvedAlbumId),
            dateAdded: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (old) => MediaTracksCompanion(
              title: Value(track.title),
              artist: Value(track.artist),
              album: Value(track.album),
              artUri: Value(effectiveArtUri),
              albumId: Value(resolvedAlbumId),
            ),
          ),
        );
      }
    });
  }

  /// Update editable metadata fields on a track.
  Future<void> updateTrack(
    int trackId, {
    String? title,
    String? artist,
    String? album,
    String? artUri,
    int? albumId,
    bool clearAlbumId = false,
    bool clearArtUri = false,
  }) async {
    final resolvedAlbumId = clearAlbumId ? null : albumId;
    final albumCover = await _albumCoverForId(resolvedAlbumId);
    await (_db.update(_db.mediaTracks)..where((t) => t.id.equals(trackId)))
        .write(MediaTracksCompanion(
      title: title != null ? Value(title) : const Value.absent(),
      artist: artist != null ? Value(artist) : const Value.absent(),
      album: album != null ? Value(album) : const Value.absent(),
      artUri: clearArtUri
          ? const Value(null)
          : (albumCover != null
              ? Value(albumCover)
              : (artUri != null ? Value(artUri) : const Value.absent())),
      albumId: clearAlbumId
          ? const Value(null)
          : (albumId != null ? Value(albumId) : const Value.absent()),
    ));
  }

  /// Get a single track by ID.
  Future<MediaTrack?> getTrack(int id) {
    final query = _db.select(_db.mediaTracks)
      ..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  /// Get a single track by file path.
  Future<MediaTrack?> getTrackByPath(String filePath) {
    final query = _db.select(_db.mediaTracks)
      ..where((t) => t.filePath.equals(filePath));
    return query.getSingleOrNull();
  }

  // ---------------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------------

  /// Watch favorite tracks.
  Stream<List<MediaTrack>> watchFavorites() {
    final query = _db.select(_db.mediaTracks)
      ..where((t) => t.isFavorite.equals(true))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return query.watch();
  }

  /// Toggle favorite status for a track.
  Future<void> toggleFavorite(int trackId) async {
    final track = await getTrack(trackId);
    if (track == null) return;

    await (_db.update(_db.mediaTracks)..where((t) => t.id.equals(trackId)))
        .write(MediaTracksCompanion(
      isFavorite: Value(!track.isFavorite),
    ));
  }

  /// Set favorite status explicitly.
  Future<void> setFavorite(int trackId, bool favorite) async {
    await (_db.update(_db.mediaTracks)..where((t) => t.id.equals(trackId)))
        .write(MediaTracksCompanion(
      isFavorite: Value(favorite),
    ));
  }

  // ---------------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------------

  /// Search tracks by title or artist.
  Future<List<MediaTrack>> searchTracks(String query) async {
    final pattern = '%$query%';
    final q = _db.select(_db.mediaTracks)
      ..where(
          (t) => t.title.like(pattern) | t.artist.like(pattern))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return q.get();
  }

  // ---------------------------------------------------------------------------
  // Play history
  // ---------------------------------------------------------------------------

  /// Mark a track as played (update lastPlayed + increment playCount).
  Future<void> markPlayed(int trackId) async {
    final track = await getTrack(trackId);
    if (track == null) return;

    await (_db.update(_db.mediaTracks)..where((t) => t.id.equals(trackId)))
        .write(MediaTracksCompanion(
      lastPlayed: Value(DateTime.now()),
      playCount: Value(track.playCount + 1),
    ));
  }

  /// Get recently played tracks.
  Future<List<MediaTrack>> getRecentlyPlayed({int limit = 30}) async {
    final query = _db.select(_db.mediaTracks)
      ..where((t) => t.lastPlayed.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastPlayed)])
      ..limit(limit);
    return query.get();
  }

  /// Watch recently played tracks.
  Stream<List<MediaTrack>> watchRecentlyPlayed({int limit = 30}) {
    final query = _db.select(_db.mediaTracks)
      ..where((t) => t.lastPlayed.isNotNull())
      ..orderBy([(t) => OrderingTerm.desc(t.lastPlayed)])
      ..limit(limit);
    return query.watch();
  }

  // ---------------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------------

  /// Watch all playlists.
  Stream<List<MediaPlaylist>> watchPlaylists() {
    final query = _db.select(_db.mediaPlaylists)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  /// Create a new playlist.
  Future<int> createPlaylist(String name) async {
    return _db.into(_db.mediaPlaylists).insert(
          MediaPlaylistsCompanion(
            name: Value(name),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  /// Rename a playlist.
  Future<void> renamePlaylist(int playlistId, String newName) async {
    await (_db.update(_db.mediaPlaylists)
          ..where((t) => t.id.equals(playlistId)))
        .write(MediaPlaylistsCompanion(name: Value(newName)));
  }

  /// Delete a playlist and its entries.
  Future<void> deletePlaylist(int playlistId) async {
    await (_db.delete(_db.mediaPlaylistEntries)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();
    await (_db.delete(_db.mediaPlaylists)
          ..where((t) => t.id.equals(playlistId)))
        .go();
  }

  /// Add a track to a playlist.
  Future<void> addToPlaylist(int playlistId, int trackId) async {
    // Get current max sortOrder
    final existing = await (_db.select(_db.mediaPlaylistEntries)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.desc(t.sortOrder)])
          ..limit(1))
        .getSingleOrNull();

    final nextOrder = (existing?.sortOrder ?? -1) + 1;

    await _db.into(_db.mediaPlaylistEntries).insert(
          MediaPlaylistEntriesCompanion(
            playlistId: Value(playlistId),
            trackId: Value(trackId),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  /// Remove an entry from a playlist.
  Future<void> removeFromPlaylist(int entryId) async {
    await (_db.delete(_db.mediaPlaylistEntries)
          ..where((t) => t.id.equals(entryId)))
        .go();
  }

  /// Watch tracks in a playlist (joined with MediaTracks).
  Stream<List<PlaylistTrackEntry>> watchPlaylistTracks(int playlistId) {
    final query = _db.select(_db.mediaPlaylistEntries).join([
      innerJoin(
        _db.mediaTracks,
        _db.mediaTracks.id.equalsExp(_db.mediaPlaylistEntries.trackId),
      ),
    ])
      ..where(_db.mediaPlaylistEntries.playlistId.equals(playlistId))
      ..orderBy([OrderingTerm.asc(_db.mediaPlaylistEntries.sortOrder)]);

    return query.watch().map((rows) => rows
        .map((row) => PlaylistTrackEntry(
              entry: row.readTable(_db.mediaPlaylistEntries),
              track: row.readTable(_db.mediaTracks),
            ))
        .toList());
  }

  /// Get playlist track count.
  Future<int> getPlaylistTrackCount(int playlistId) async {
    final count = _db.mediaPlaylistEntries.id.count();
    final query = _db.selectOnly(_db.mediaPlaylistEntries)
      ..addColumns([count])
      ..where(_db.mediaPlaylistEntries.playlistId.equals(playlistId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Albums
  // ---------------------------------------------------------------------------

  /// Watch all albums ordered by creation date (newest first).
  Stream<List<MediaAlbum>> watchAlbums() {
    final query = _db.select(_db.mediaAlbums)
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);
    return query.watch();
  }

  /// Create a new album. Returns the new album ID.
  Future<int> createAlbum(String name, {String? coverArt}) async {
    return _db.into(_db.mediaAlbums).insert(
          MediaAlbumsCompanion(
            name: Value(name),
            coverArt: Value(coverArt),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  /// Update album name and/or cover art.
  Future<void> updateAlbum(
    int albumId, {
    String? name,
    String? coverArt,
    bool clearCoverArt = false,
  }) async {
    await (_db.update(_db.mediaAlbums)..where((t) => t.id.equals(albumId)))
        .write(MediaAlbumsCompanion(
      name: name != null ? Value(name) : const Value.absent(),
      coverArt: clearCoverArt
          ? const Value(null)
          : (coverArt != null ? Value(coverArt) : const Value.absent()),
    ));

    if (clearCoverArt || coverArt != null) {
      await (_db.update(_db.mediaTracks)
            ..where((t) => t.albumId.equals(albumId)))
          .write(
        MediaTracksCompanion(
          artUri: clearCoverArt ? const Value(null) : Value(coverArt),
        ),
      );
    }
  }

  /// Delete an album. Tracks are kept in the library but detached from the
  /// album (albumId set to null).
  Future<void> deleteAlbum(int albumId) async {
    await (_db.update(_db.mediaTracks)
          ..where((t) => t.albumId.equals(albumId)))
        .write(const MediaTracksCompanion(albumId: Value(null)));
    await (_db.delete(_db.mediaAlbums)..where((t) => t.id.equals(albumId)))
        .go();
  }

  /// Watch tracks belonging to an album ordered by title.
  Stream<List<MediaTrack>> watchAlbumTracks(int albumId) {
    final query = _db.select(_db.mediaTracks)
      ..where((t) => t.albumId.equals(albumId))
      ..orderBy([(t) => OrderingTerm.asc(t.title)]);
    return query.watch();
  }

  /// Get album track count.
  Future<int> getAlbumTrackCount(int albumId) async {
    final count = _db.mediaTracks.id.count();
    final query = _db.selectOnly(_db.mediaTracks)
      ..addColumns([count])
      ..where(_db.mediaTracks.albumId.equals(albumId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// Find an album by exact name (used to dedupe M3U imports).
  Future<MediaAlbum?> findAlbumByName(String name) async {
    final query = _db.select(_db.mediaAlbums)
      ..where((t) => t.name.equals(name))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<String?> _albumCoverForId(int? albumId) async {
    if (albumId == null) return null;
    final album = await (_db.select(_db.mediaAlbums)
          ..where((t) => t.id.equals(albumId))
          ..limit(1))
        .getSingleOrNull();
    return album?.coverArt;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Delete a track from the library entirely (manual user action only).
  Future<void> deleteTrack(int trackId) async {
    await (_db.delete(_db.mediaPlaylistEntries)
          ..where((t) => t.trackId.equals(trackId)))
        .go();
    await (_db.delete(_db.mediaTracks)..where((t) => t.id.equals(trackId)))
        .go();
  }
}

/// Combined playlist entry + track data.
class PlaylistTrackEntry {
  const PlaylistTrackEntry({required this.entry, required this.track});

  final MediaPlaylistEntry entry;
  final MediaTrack track;
}

// ---------------------------------------------------------------------------
// Riverpod Provider
// ---------------------------------------------------------------------------

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(ref.watch(databaseProvider));
});
