import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bundled asset names shipped inside the APK.
const _bundledGlyphs = <String>[
  'assets/map/glyphs/Noto Sans Regular/0-255.pbf',
  'assets/map/glyphs/Noto Sans Regular/256-511.pbf',
  'assets/map/glyphs/Noto Sans Medium/0-255.pbf',
  'assets/map/glyphs/Noto Sans Medium/256-511.pbf',
  'assets/map/glyphs/Noto Sans Italic/0-255.pbf',
  'assets/map/glyphs/Noto Sans Italic/256-511.pbf',
];

const _bundledSprites = <String>[
  'assets/map/sprite/dark.json',
  'assets/map/sprite/dark.png',
  'assets/map/sprite/dark@2x.json',
  'assets/map/sprite/dark@2x.png',
  'assets/map/sprite/light.json',
  'assets/map/sprite/light.png',
  'assets/map/sprite/light@2x.json',
  'assets/map/sprite/light@2x.png',
];

/// Extracts bundled map assets (glyphs, sprites) to the application
/// documents directory on first launch so MapLibre can reference them
/// via absolute `file://` URLs.
class MapAssetManager {
  Directory? _rootDir;
  bool _ready = false;

  /// Root directory containing `glyphs/` and `sprite/`.
  Directory get rootDir {
    final r = _rootDir;
    if (r == null) {
      throw StateError('MapAssetManager not initialised — call ensureAssets()');
    }
    return r;
  }

  bool get isReady => _ready;

  /// Absolute base URL for style JSON `glyphs` field.
  String get glyphsBaseUrl =>
      'file://${p.join(rootDir.path, 'glyphs').replaceAll('\\', '/')}';

  /// Absolute base URL for style JSON `sprite` field (no extension).
  String spriteBaseUrl(String theme) =>
      'file://${p.join(rootDir.path, 'sprite', theme).replaceAll('\\', '/')}';

  /// Extracts assets if they aren't already on disk. Idempotent.
  Future<void> ensureAssets() async {
    if (_ready) return;
    try {
      final docs = await getApplicationDocumentsDirectory();
      final root = Directory(p.join(docs.path, 'map_assets'));
      _rootDir = root;

      final marker = File(p.join(root.path, '.ready_v1'));
      if (await marker.exists()) {
        _ready = true;
        return;
      }

      for (final asset in [..._bundledGlyphs, ..._bundledSprites]) {
        final rel = asset.replaceFirst('assets/map/', '');
        final dst = File(p.join(root.path, rel));
        await dst.parent.create(recursive: true);
        final bytes = await rootBundle.load(asset);
        await dst.writeAsBytes(bytes.buffer.asUint8List(
          bytes.offsetInBytes,
          bytes.lengthInBytes,
        ));
      }

      await marker.create(recursive: true);
      _ready = true;
      debugPrint('MapAssetManager: extracted ${_bundledGlyphs.length + _bundledSprites.length} assets to ${root.path}');
    } catch (e, st) {
      debugPrint('MapAssetManager.ensureAssets error: $e\n$st');
      rethrow;
    }
  }
}

final mapAssetManagerProvider = Provider<MapAssetManager>((_) {
  return MapAssetManager();
});
