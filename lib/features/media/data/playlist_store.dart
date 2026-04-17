import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'package:drivelink/core/services/audio_service.dart';

/// Persists the scanned playlist to a JSON file so it survives app restarts.
class PlaylistStore {
  PlaylistStore._();

  static const _fileName = 'drivelink_playlist.json';

  static Future<File> get _file async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// Save the current playlist, track metadata, and last-played index.
  static Future<void> save({
    required List<String> paths,
    required List<TrackInfo> trackInfos,
    required int lastIndex,
  }) async {
    final file = await _file;
    final data = {
      'paths': paths,
      'tracks': trackInfos
          .map((t) => {
                'title': t.title,
                'artist': t.artist,
                'artUri': t.artUri,
              })
          .toList(),
      'lastIndex': lastIndex,
    };
    await file.writeAsString(jsonEncode(data));
  }

  /// Load the persisted playlist. Returns null if nothing saved or if the
  /// file is corrupt.
  static Future<SavedPlaylist?> load() async {
    try {
      final file = await _file;
      if (!file.existsSync()) return null;

      final raw = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final paths =
          (raw['paths'] as List).map((e) => e as String).toList();
      final tracks = (raw['tracks'] as List)
          .map((t) => TrackInfo(
                title: (t as Map<String, dynamic>)['title'] as String? ??
                    'Bilinmeyen',
                artist: t['artist'] as String? ?? '',
                artUri: t['artUri'] as String?,
              ))
          .toList();
      final lastIndex = (raw['lastIndex'] as int?) ?? 0;

      if (paths.isEmpty) return null;

      return SavedPlaylist(
        paths: paths,
        trackInfos: tracks,
        lastIndex: lastIndex.clamp(0, paths.length - 1),
      );
    } catch (_) {
      return null;
    }
  }

  /// Update only the last-played index (fast, no full rewrite of tracks).
  static Future<void> updateLastIndex(int index) async {
    try {
      final file = await _file;
      if (!file.existsSync()) return;
      final raw =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      raw['lastIndex'] = index;
      await file.writeAsString(jsonEncode(raw));
    } catch (_) {
      // Best-effort — don't crash playback for a save failure.
    }
  }
}

class SavedPlaylist {
  const SavedPlaylist({
    required this.paths,
    required this.trackInfos,
    required this.lastIndex,
  });

  final List<String> paths;
  final List<TrackInfo> trackInfos;
  final int lastIndex;
}
