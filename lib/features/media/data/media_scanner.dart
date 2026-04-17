import 'dart:io';

import 'package:drivelink/features/media/data/m3u_parser.dart';
import 'package:drivelink/features/media/data/media_repository.dart';

/// Result of a media scan operation.
class ScanResult {
  const ScanResult({
    required this.tracks,
    required this.m3uFiles,
  });

  final List<ScannedTrack> tracks;
  final List<File> m3uFiles;

  int get trackCount => tracks.length;
  bool get hasM3u => m3uFiles.isNotEmpty;
}

/// Scans standard Android music directories for audio files and M3U playlists.
class MediaScanner {
  MediaScanner._();

  static const audioExtensions = {
    '.mp3', '.m4a', '.wav', '.flac', '.ogg', '.aac', '.wma',
  };
  static const _m3uExtensions = {'.m3u', '.m3u8'};

  static const musicDirs = [
    '/storage/emulated/0/Music',
    '/storage/emulated/0/Download',
    '/storage/emulated/0/Downloads',
    '/storage/emulated/0/Playlists',
    '/sdcard/Music',
    '/sdcard/Download',
    '/sdcard/Downloads',
  ];

  /// Cover-art file names to look for in a track's directory.
  static const _coverArtNames = [
    'cover.jpg', 'cover.png', 'cover.jpeg',
    'folder.jpg', 'folder.png', 'folder.jpeg',
    'front.jpg', 'front.png', 'front.jpeg',
    'album.jpg', 'album.png', 'album.jpeg',
    'AlbumArt.jpg', 'artwork.jpg', 'artwork.png',
  ];

  /// Per-directory cache so we only stat cover-art files once per scan.
  static final _coverCache = <String, String?>{};

  /// Scan all standard directories for audio files and M3U playlists.
  static Future<ScanResult> scan() async {
    final audioFiles = <File>[];
    final m3uFiles = <File>[];
    _coverCache.clear();

    for (final dirPath in musicDirs) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;
      try {
        await for (final entity
            in dir.list(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          final ext = _extension(entity.path);
          if (audioExtensions.contains(ext)) {
            audioFiles.add(entity);
          } else if (_m3uExtensions.contains(ext)) {
            m3uFiles.add(entity);
          }
        }
      } catch (_) {}
    }

    // Sort audio files alphabetically
    audioFiles.sort((a, b) => a.uri.pathSegments.last
        .toLowerCase()
        .compareTo(b.uri.pathSegments.last.toLowerCase()));

    final tracks = audioFiles.map((file) {
      final title = titleFromPath(file.path);
      final art = findCoverArt(file.path);
      return ScannedTrack(
        filePath: file.path,
        title: title,
        artist: '',
        artUri: art,
      );
    }).toList();

    return ScanResult(tracks: tracks, m3uFiles: m3uFiles);
  }

  /// Parse an M3U file and return scanned tracks.
  static Future<List<ScannedTrack>> parseM3u(File m3uFile) async {
    final m3uTracks = await M3uParser.parseFile(m3uFile);
    return m3uTracks.map((t) {
      final title = t.title ?? titleFromPath(t.path);
      final artist = t.artist ?? '';
      final art = findCoverArt(t.path);
      return ScannedTrack(
        filePath: t.path,
        title: title,
        artist: artist,
        artUri: art,
      );
    }).toList();
  }

  /// Derive an album name from an M3U file (filename without extension).
  static String albumNameFromM3u(File m3uFile) {
    final name = m3uFile.uri.pathSegments.last;
    final dotIdx = name.lastIndexOf('.');
    return dotIdx > 0 ? name.substring(0, dotIdx) : name;
  }

  /// Pick a cover image for an M3U album: prefer a cover file in the M3U
  /// directory, otherwise fall back to the first track's cover.
  static String? albumCoverFromM3u(File m3uFile, List<ScannedTrack> tracks) {
    final dirCover = findCoverArt('${m3uFile.parent.path}/_dummy.mp3');
    if (dirCover != null) return dirCover;
    for (final t in tracks) {
      if (t.artUri != null && t.artUri!.isNotEmpty) return t.artUri;
    }
    return null;
  }

  /// Look for common cover-art files in the same directory as [audioFilePath].
  static String? findCoverArt(String audioFilePath) {
    final dirPath = File(audioFilePath).parent.path;
    if (_coverCache.containsKey(dirPath)) return _coverCache[dirPath];

    for (final name in _coverArtNames) {
      final file = File('$dirPath/$name');
      if (file.existsSync()) {
        _coverCache[dirPath] = file.path;
        return file.path;
      }
    }
    _coverCache[dirPath] = null;
    return null;
  }

  /// Extract a display title from a file path (filename without extension).
  static String titleFromPath(String path) {
    final name = path.split('/').last;
    final dotIdx = name.lastIndexOf('.');
    return dotIdx > 0 ? name.substring(0, dotIdx) : name;
  }

  static String _extension(String path) {
    final dotIdx = path.lastIndexOf('.');
    if (dotIdx < 0) return '';
    return path.substring(dotIdx).toLowerCase();
  }
}
