import 'dart:io';

/// A single track entry parsed from an M3U playlist.
class M3uTrack {
  const M3uTrack({
    required this.path,
    this.title,
    this.artist,
    this.durationSeconds,
  });

  /// Absolute path to the audio file.
  final String path;

  /// Track title (from `#EXTINF` or filename).
  final String? title;

  /// Artist name (from `#EXTINF` "Artist - Title" format).
  final String? artist;

  /// Duration in seconds (from `#EXTINF`).
  final int? durationSeconds;
}

/// Parses M3U and M3U8 playlist files.
///
/// Supports both simple (path-only) and extended (`#EXTM3U` / `#EXTINF`)
/// formats. Relative paths are resolved against the M3U file's directory.
/// Only tracks whose files actually exist on disk are returned.
class M3uParser {
  M3uParser._();

  /// Parse an M3U file and return its tracks (only existing files).
  static Future<List<M3uTrack>> parseFile(File m3uFile) async {
    if (!m3uFile.existsSync()) return [];

    final content = await m3uFile.readAsString();
    final m3uDir = m3uFile.parent.path;

    return parse(content, m3uDir);
  }

  /// Parse M3U content string. [baseDirectory] is used to resolve relative
  /// paths.
  static List<M3uTrack> parse(String content, String baseDirectory) {
    final tracks = <M3uTrack>[];
    final lines = content.split(RegExp(r'\r?\n'));

    String? pendingTitle;
    String? pendingArtist;
    int? pendingDuration;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Extended info: #EXTINF:duration,display_title
      if (line.toUpperCase().startsWith('#EXTINF:')) {
        final afterPrefix = line.substring(8);
        final commaIdx = afterPrefix.indexOf(',');
        if (commaIdx > 0) {
          pendingDuration =
              int.tryParse(afterPrefix.substring(0, commaIdx).trim());
          final display = afterPrefix.substring(commaIdx + 1).trim();

          // Try "Artist - Title" split
          final dashIdx = display.indexOf(' - ');
          if (dashIdx > 0) {
            pendingArtist = display.substring(0, dashIdx).trim();
            pendingTitle = display.substring(dashIdx + 3).trim();
          } else {
            pendingTitle = display;
            pendingArtist = null;
          }
        }
        continue;
      }

      // Skip other directives and comments
      if (line.startsWith('#')) continue;

      // This is a file path — resolve it
      var filePath = line.replaceAll('\\', '/');

      // Skip URLs (http/https streams)
      if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
        pendingTitle = null;
        pendingArtist = null;
        pendingDuration = null;
        continue;
      }

      // Resolve relative paths against the M3U file's directory
      if (!filePath.startsWith('/')) {
        filePath = '$baseDirectory/$filePath';
      }

      // Normalise (collapse ../ etc.)
      filePath = _normalisePath(filePath);

      // Only include if file exists
      if (File(filePath).existsSync()) {
        tracks.add(M3uTrack(
          path: filePath,
          title: pendingTitle ?? _titleFromPath(filePath),
          artist: pendingArtist,
          durationSeconds: pendingDuration,
        ));
      }

      pendingTitle = null;
      pendingArtist = null;
      pendingDuration = null;
    }

    return tracks;
  }

  /// Extract a display title from a file path (filename without extension).
  static String _titleFromPath(String path) {
    final name = path.split('/').last;
    final dotIdx = name.lastIndexOf('.');
    return dotIdx > 0 ? name.substring(0, dotIdx) : name;
  }

  /// Collapse `..` and `.` segments in a path.
  static String _normalisePath(String path) {
    final parts = path.split('/');
    final result = <String>[];
    for (final part in parts) {
      if (part == '.' || part.isEmpty) continue;
      if (part == '..' && result.isNotEmpty && result.last != '..') {
        result.removeLast();
      } else {
        result.add(part);
      }
    }
    // Preserve leading slash for absolute paths
    final prefix = path.startsWith('/') ? '/' : '';
    return '$prefix${result.join('/')}';
  }
}
