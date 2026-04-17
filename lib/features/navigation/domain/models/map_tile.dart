import 'dart:typed_data';

/// A single map tile fetched from the tile server or local cache.
class MapTile {
  const MapTile({
    required this.z,
    required this.x,
    required this.y,
    required this.bytes,
  });

  /// Zoom level.
  final int z;

  /// Tile column.
  final int x;

  /// Tile row.
  final int y;

  /// Raw image bytes (PNG).
  final Uint8List bytes;

  /// Standard slippy-map tile key for cache lookups.
  String get key => '$z/$x/$y';

  @override
  String toString() => 'MapTile($key, ${bytes.length} bytes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapTile &&
          runtimeType == other.runtimeType &&
          z == other.z &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(z, x, y);
}
