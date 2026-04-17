import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drivelink/core/services/map_asset_manager.dart';
import 'package:drivelink/core/services/turkey_package_service.dart';

/// Which visual style to load.
enum MapStyle { dark, light, satellite }

/// Builds fully-resolved MapLibre style JSON strings with all resources
/// (tiles, glyphs, sprite) pointing to local `file://` URLs.
///
/// If the Turkey package is not yet installed, tiles fall back to an empty
/// placeholder source — the map background renders but no vector data shows.
class MapStyleLoader {
  MapStyleLoader(this._assets, this._package);

  final MapAssetManager _assets;
  final TurkeyPackageService _package;

  /// Loads and resolves a style JSON as a string ready to pass to
  /// `MapLibreMap(styleString: ...)`.
  Future<String> load(MapStyle style) async {
    await _assets.ensureAssets();

    final assetPath = switch (style) {
      MapStyle.dark => 'assets/map/dark_style.json',
      MapStyle.light => 'assets/map/light_style.json',
      MapStyle.satellite => 'assets/map/satellite_style.json',
    };

    var json = await rootBundle.loadString(assetPath);

    // Satellite style doesn't use placeholders — it's fully self-contained
    // (online tiles for now; a dedicated offline satellite pack is future work).
    if (style == MapStyle.satellite) return json;

    final theme = style == MapStyle.dark ? 'dark' : 'light';
    final glyphsUrl = _assets.glyphsBaseUrl;
    final spriteUrl = _assets.spriteBaseUrl(theme);
    final tileUrl = await _resolveTileUrl();

    json = json
        .replaceAll('{{GLYPHS_URL}}', glyphsUrl)
        .replaceAll('{{SPRITE_URL}}', spriteUrl)
        .replaceAll('{{TILE_URL}}', tileUrl);

    return json;
  }

  /// Returns the `pmtiles://file://...` URL for the installed Turkey pack,
  /// or a harmless data URI if not yet installed (map still loads; no vector
  /// features will appear, just the background colour).
  Future<String> _resolveTileUrl() async {
    final pmtilesPath = await _package.installedPmtilesPath();
    if (pmtilesPath != null) {
      final unix = pmtilesPath.replaceAll('\\', '/');
      return 'pmtiles://file://$unix';
    }
    // Minimal empty TileJSON served via a data URI so MapLibre doesn't error.
    return _emptyTileJsonDataUri;
  }
}

/// Data URI for an empty TileJSON — renders no tiles, no errors.
const _emptyTileJsonDataUri =
    'data:application/json;charset=utf-8,'
    '%7B%22tilejson%22%3A%222.2.0%22%2C%22tiles%22%3A%5B%5D%2C'
    '%22minzoom%22%3A0%2C%22maxzoom%22%3A15%7D';

final mapStyleLoaderProvider = Provider<MapStyleLoader>((ref) {
  return MapStyleLoader(
    ref.watch(mapAssetManagerProvider),
    ref.watch(turkeyPackageServiceProvider),
  );
});

/// Helper for legacy call sites that only need a theme → style resolver.
Future<String> loadMapStyle(WidgetRef ref, MapStyle style) {
  return ref.read(mapStyleLoaderProvider).load(style);
}

/// Cycle to the next map style.
MapStyle nextMapStyle(MapStyle current) => switch (current) {
      MapStyle.dark => MapStyle.light,
      MapStyle.light => MapStyle.satellite,
      MapStyle.satellite => MapStyle.dark,
    };

/// Icon for the given [MapStyle].
IconData mapStyleIcon(MapStyle style) => switch (style) {
      MapStyle.dark => Icons.dark_mode,
      MapStyle.light => Icons.light_mode,
      MapStyle.satellite => Icons.satellite_alt,
    };
