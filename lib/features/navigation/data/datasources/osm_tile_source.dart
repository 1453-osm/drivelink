/// Utility class — only normalizeRegionName is used now.
/// Actual offline map operations are handled by OfflineMapService.
class OsmTileSource {
  static String normalizeRegionName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
